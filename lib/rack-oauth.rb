require 'rubygems'
require 'rack'
require 'oauth'

module Rack #:nodoc:

  # Rack Middleware for integrating OAuth into your application
  #
  # Note: this *requires* that a Rack::Session middleware be enabled
  #
  class OAuth

    # Helper methods intended to be included in your Rails controller or 
    # in your Sinatra helpers block
    module Methods
      
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
      def oauth name = nil
        oauth = Rack::OAuth.get(oauth_request_env, nil)
        raise "Couldn't find Rack::OAuth instance with name #{ name }" unless oauth
        oauth
      end

      # Makes a request using the stored access token for the current session.
      #
      # Without a user logged in to an OAuth provider in the current session, this won't work.
      #
      # This is *not* the method to use to fire off requests for saved access tokens.
      def oauth_request *args
        oauth.request oauth_request_env, *args
      end

      # If Rack::OAuth#get_access_token is nil given the #oauth_request_env available
      # (inotherwords, it's nil in our user's current session), then we didn't 
      # log in.  If we have an access token for this particular session, then 
      # we are logged in.
      def logged_in? name = nil
        !! oauth(name).get_access_token(oauth_request_env)
      end

      # Returns the path to rediret to for logging in via OAuth
      def oauth_login_path name = nil
        oauth(name).login_path
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
      :login_path          => '/oauth_login',
      :callback_path       => '/oauth_callback',
      :redirect_to         => '/oauth_complete',
      :rack_session        => 'rack.session',
      :json_parser         => lambda {|json_string| require 'json'; JSON.parse(json_string); },
      :access_token_getter => lambda {|key, oauth| oauth.get_access_token_via_instance_variable(key) },
      :access_token_setter => lambda {|key, token, oauth| oauth.set_access_token_via_instance_variable(key, token) }
    }

    # A proc that accepts an argument for the KEY we're using to get an access token 
    # that should return the actual access token object.
    #
    # A second parameter is passed to your block with the Rack::OAuth instance
    #
    # This allows you to override how access tokens are persisted
    attr_accessor :access_token_getter
    alias get  access_token_getter
    alias get= access_token_getter=

    # A proc that accepts an argument for the KEY we're using to set an access token 
    # and a second argument with the actual access token object.
    #
    # A third parameter is passed to your block with the Rack::OAuth instance
    #
    # This allows you to override how access tokens are persisted
    attr_accessor :access_token_setter
    alias set  access_token_setter
    alias set= access_token_setter=

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

    # a Proc that accepts a JSON string and returns a Ruby object.  Defaults to using the 'json' gem, if available.
    attr_accessor :json_parser

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
      env['rack.oauth'] ||= {}
      env['rack.oauth'][name] = self

      case env['PATH_INFO']
      when login_path;      do_login     env
      when callback_path;   do_callback  env
      else;                 @app.call    env
      end
    end

    def do_login env

      if Rack::OAuth.test_mode?
        session(env)[:token]  = "Token" 
        session(env)[:secret] = "Secret"
        set_access_token env, "AccessToken"
        return [ 302, { 'Content-Type' => 'text/html', 'Location' => redirect_to }, [] ]
      end

      request = consumer.get_request_token :oauth_callback => ::File.join("http://#{ env['HTTP_HOST'] }", callback_path)
      session(env)[:token]  = request.token
      session(env)[:secret] = request.secret
      [ 302, { 'Content-Type' => 'text/html', 'Location' => request.authorize_url }, [] ]
    end

    def do_callback env
      session(env)[:verifier] = Rack::Request.new(env).params['oauth_verifier']
      request = ::OAuth::RequestToken.new consumer, session(env)[:token], session(env)[:secret]
      access  = request.get_access_token :oauth_verifier => session(env)[:verifier]
      set_access_token env, access

      # TESTING
      session(env)[:credentials] = request env, '/account/verify_credentials.json'

      puts 'credentials:'
      puts session(env)[:credentials]

      [ 302, { 'Content-Type' => 'text/html', 'Location' => redirect_to }, [] ]
    end

    # Default implementation of access_token_getter
    #
    # Keeps tokens in an instance variable
    def get_access_token_via_instance_variable key
      puts "get_access_token_via_instance_variable #{ key }"
      @tokens[key] if @tokens
    end

    # Default implementation of access_token_setter
    #
    # Keeps tokens in an instance variable
    def set_access_token_via_instance_variable key, token
      @tokens ||= {}
      @tokens[key] = token
    end

    # Returns the key to use (for this particular session) to get or set an 
    # access token for this Rack env
    #
    # TODO this will very likely change as we want to be able to get or set 
    #      access tokens using useful data like a user's name in the future
    def key_for_env env
      val = session(env)[:token] + session(env)[:secret] if session(env)[:token] and session(env)[:secret]
      puts "key_for_env => #{ val }"
      session(env)[:token] + session(env)[:secret] if session(env)[:token] and session(env)[:secret]
    end

    # Gets an Access Token by key using access_token_getter (for this specific ENV)
    def get_access_token env
      puts "get_access_token"
      access_token_getter.call key_for_env(env), self
    end

    # Sets an Access Token by key and value using access_token_setter (for this specific ENV)
    def set_access_token env, token
      access_token_setter.call key_for_env(env), token, self
    end

    # Usage:
    #
    #   request '/account/verify_credentials.json'
    #   request 'GET', '/account/verify_credentials.json'
    #   request :post, '/statuses/update.json', :status => params[:tweet]
    #
    def request env, method, path = nil, *args
      if method.to_s.start_with?('/')
        path   = method
        method = :get
      end

      return Rack::OAuth.mock_response_for(method, path) if Rack::OAuth.test_mode?

      consumer.request method.to_s.downcase.to_sym, path, get_access_token(env), *args
    end

    # ...
    def self.mock_response_for method, path
      unless @mock_responses and @mock_responses[path] and @mock_responses[path][method]
        raise "No mock response created for #{ method.inspect } #{ path.inspect }"
      else
        return @mock_responses[path][method]
      end
    end

    # ...
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
