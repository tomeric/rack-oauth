require 'rubygems'
require 'rack'
require 'oauth'

# For some reason, getting the location our of a HeaderHash doesn't always work!
#
# sometimes you can see the header key/value in the HeaderHash, but you can't get it out!
class Rack::Utils::HeaderHash
  def [] key
    if not has_key?(key)
      hash = to_hash
      hash.keys.each do |hash_key|
        if hash_key.downcase == key.downcase
          return hash[hash_key]
        end
      end
    end
    super
  end
end

module Rack #:nodoc:

  # Rack Middleware for integrating OAuth into your application
  #
  # Note: this *requires* that a Rack::Session middleware be enabled
  #
  class OAuth

    # Helper methods intended to be included in your Rails controller or 
    # in your Sinatra helpers block
    module Methods

      # This is *the* method you want to call.
      #
      # After you're authorized and redirected back to your #redirect_to path, 
      # you should be able to call get_access_token to get and hold onto 
      # the access token for the user you've been authorized as.
      #
      # You can use the token to make GET/POST/etc requests
      def get_access_token name = nil
        oauth_instance(name).get_access_token(oauth_request_env)
      end

      # Same as #get_access_token but it clears the access token out of the session.
      def get_access_token! name = nil
        oauth_instance(name).get_access_token!(oauth_request_env)
      end
      
      # [Internal] this method returns the Rack 'env' for the current request.
      #
      # This looks for #env or #request.env by default.  If these don't return 
      # something, then we raise an exception and you should override this method 
      # so it returns the Rack env that we need.
      def oauth_request_env
        if respond_to?(:env)
          env
        elsif respond_to?(:request) and request.respond_to?(:env)
          request.env
        else
          raise "Couldn't find 'env' ... please override #oauth_request_env"
        end
      end

      # Returns the instance of Rack::OAuth given a name (defaults to the default Rack::OAuth name)
      def oauth_instance name = nil
        oauth = Rack::OAuth.get(oauth_request_env, nil)
        raise "Couldn't find Rack::OAuth instance with name #{ name }" unless oauth
        oauth
      end

      # Returns the path to rediret to for logging in via OAuth
      def oauth_login_path name = nil
        oauth_instance(name).login_path
      end

    end

    class << self

      # The name we use for Rack::OAuth instances when a name is not given.
      #
      # This is 'default' by default
      attr_accessor :default_instance_name

      # Set this equal to true to enable 'test mode'
      attr_accessor :test_mode_enabled
      def enable_test_mode()  self.test_mode_enabled =  true  end
      def disable_test_mode() self.test_mode_enabled =  false end
      def test_mode?()             test_mode_enabled == true  end
    end

    @default_instance_name = 'default'

    # Returns all of the Rack::OAuth instances found in this Rack 'env' Hash
    def self.all env
      env['rack.oauth']
    end

    # Simple helper to get an instance of Rack::OAuth by name found in this Rack 'env' Hash
    def self.get env, name = nil
      name = Rack::OAuth.default_instance_name if name.nil?
      all(env)[name.to_s]
    end

    DEFAULT_OPTIONS = {
      :login_path    => '/oauth_login',
      :callback_path => '/oauth_callback',
      :redirect_to   => '/oauth_complete',
      :rack_session  => 'rack.session'
    }

    # the URL that should initiate OAuth and redirect to the OAuth provider's login page
    def login_path
      ::File.join *[@login_path.to_s, name_unless_default].compact
    end
    attr_writer :login_path
    alias login  login_path
    alias login= login_path=

    # the URL that the OAuth provider should callback to after OAuth login is complete
    def callback_path
      ::File.join *[@callback_path.to_s, name_unless_default].compact
    end
    attr_writer :callback_path
    alias callback  callback_path
    alias callback= callback_path=

    # the URL that Rack::OAuth should redirect to after the OAuth has been completed (part of your app)
    attr_accessor :redirect_to
    alias redirect  redirect_to
    alias redirect= redirect_to=

    # the name of the Rack env variable used for the session
    attr_accessor :rack_session

    # [required] Your OAuth consumer key
    attr_accessor :consumer_key
    alias key  consumer_key
    alias key= consumer_key=

    # [required] Your OAuth consumer secret
    attr_accessor :consumer_secret
    alias secret  consumer_secret
    alias secret= consumer_secret=

    # [required] The site you want to request OAuth for, eg. 'http://twitter.com'
    attr_accessor :consumer_site
    alias site  consumer_site
    alias site= consumer_site=

    # an arbitrary name for this instance of Rack::OAuth
    def name
      @name.to_s
    end
    attr_writer :name

    def initialize app, *args
      @app = app

      options = args.pop
      @name   = args.first || Rack::OAuth.default_instance_name
      
      DEFAULT_OPTIONS.each {|name, value| send "#{name}=", value }
      options.each         {|name, value| send "#{name}=", value } if options

      raise_validation_exception unless valid?
    end

    def call env
      # put this instance of Rack::OAuth in the env 
      # so it's accessible from the application
      env['rack.oauth'] ||= {}
      env['rack.oauth'][name] = self

      case env['PATH_INFO']
      
      # find out where to redirect to authorize for this oauth provider 
      # and redirect there.  when the authorization is finished, 
      # the provider will redirect back to our application's callback path
      when login_path
        do_login(env)

      # the oauth provider has redirected back to us!  we should have a 
      # verifier now that we can use, in combination with out token and 
      # secret, to get an access token for this user
      when callback_path
        do_callback(env)

      else
        @app.call(env)
      end
    end

    def do_login env
      if Rack::OAuth.test_mode?
        set_access_token env, OpenStruct.new(:params => { 'I am a' => 'fake token' })
        return [ 302, { 'Content-Type' => 'text/html', 'Location' => redirect_to }, [] ]
      end

      # get request token and hold onto the token/secret (which we need later to get the access token)
      request = consumer.get_request_token :oauth_callback => ::File.join("http://#{ env['HTTP_HOST'] }", callback_path)
      session(env)[:token]  = request.token
      session(env)[:secret] = request.secret

      # redirect to the oauth provider's authorize url to authorize the user
      [ 302, { 'Content-Type' => 'text/html', 'Location' => request.authorize_url }, [] ]
    end

    def do_callback env
      # get access token and persist it in the session in a way that we can get it back out later
      request = ::OAuth::RequestToken.new consumer, session(env)[:token], session(env)[:secret]
      set_access_token env, request.get_access_token(:oauth_verifier => Rack::Request.new(env).params['oauth_verifier'])

      # clear out the session variables (won't need these anymore)
      session(env).delete(:token)
      session(env).delete(:secret)

      # we have an access token now ... redirect back to the user's application
      [ 302, { 'Content-Type' => 'text/html', 'Location' => redirect_to }, [] ]
    end

    # Stores the access token in this env's session in a way that we can get it back out via #get_access_token(env)
    def set_access_token env, token
      session(env)[:access_token_params] = token.params
    end

    # See #set_access_token
    def get_access_token env
      params = session(env)[:access_token_params]
      ::OAuth::AccessToken.from_hash consumer, params if params
    end

    # Same as #get_access_token but it clears the access token info out of the session
    def get_access_token! env
      params = session(env).delete(:access_token_params)
      ::OAuth::AccessToken.from_hash consumer, params if params
    end

    # Usage:
    #
    #   request @token, '/account/verify_credentials.json'
    #   request @token, 'GET', '/account/verify_credentials.json'
    #   request @token, :post, '/statuses/update.json', :status => params[:tweet]
    #
    def request token, method, path = nil, *args
      if method.to_s.start_with?('/')
        path   = method
        method = :get
      end

      return Rack::OAuth.mock_response_for(method, path) if Rack::OAuth.test_mode?

      consumer.request method.to_s.downcase.to_sym, path, token, *args
    end

    # Returns the mock response, if one has been set via #mock_request, for a method and path.
    #
    # Raises an exception if the response doesn't exist because we never want the test environment 
    # to *actually* make real requests!
    def self.mock_response_for method, path
      unless @mock_responses and @mock_responses[path] and @mock_responses[path][method]
        raise "No mock response created for #{ method.inspect } #{ path.inspect }"
      else
        return @mock_responses[path][method]
      end
    end

    # Set the response that should be returned when a particular method and path are called.
    #
    # This is used when Rack::OAuth::test_mode? is true
    def self.mock_request method, path, response = nil
      if method.to_s.start_with?('/')
        response = path
        path     = method
        method   = :get
      end

      @mock_responses ||= {}
      @mock_responses[path] ||= {}
      @mock_responses[path][method] = response
    end

    def verified? env
      [ :token, :secret, :verifier ].all? { |required_session_key| session(env)[required_session_key] }
    end

    def consumer
      @consumer ||= ::OAuth::Consumer.new consumer_key, consumer_secret, :site => consumer_site
    end

    def valid?
      @errors = []
      @errors << ":consumer_key option is required"    unless consumer_key
      @errors << ":consumer_secret option is required" unless consumer_secret
      @errors << ":consumer_site option is required"   unless consumer_site
      @errors.empty?
    end

    def raise_validation_exception
      raise @errors.join(', ')
    end

    # Returns a hash of session variables, specific to this instance of Rack::OAuth and the end-user
    #
    # All user-specific variables are stored in the session.
    #
    # The variables we currently keep track of are:
    # - token
    # - secret
    # - verifier
    #
    # With all three of these, we can make arbitrary requests to our OAuth provider for this user.
    def session env
      raise "Rack env['rack.session'] is nil ... has a Rack::Session middleware be enabled?  " + 
            "use :rack_session for custom key" if env[rack_session].nil?      
      env[rack_session]['rack.oauth']       ||= {}
      env[rack_session]['rack.oauth'][name] ||= {}
    end

    # Returns the #name of this Rack::OAuth unless the name is 'default', in which case it returns nil
    def name_unless_default
      name == Rack::OAuth.default_instance_name ? nil : name
    end

  end

end
