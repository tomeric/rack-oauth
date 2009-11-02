require 'rubygems'
require 'rack'
require 'oauth'

module Rack #:nodoc:

  # Rack Middleware for integrating OAuth into your application
  #
  # Note: this *requires* that a Rack::Session middleware be enabled
  #
  class OAuth

    # helper methods
    module Methods
      
      def request_env
        if respond_to?(:env)
          env
        elsif respond_to?(:request) and request.respond_to?(:env)
          request.env
        else
          raise "Couldn't find 'env' ... please override #request_env"
        end
      end

      def oauth name = :default
        oauth = Rack::OAuth.get(request_env, name)
        raise "Couldn't find Rack::OAuth instance with name #{ name }" unless oauth
        oauth
      end

      def oauth_request *args
        oauth.request request_env, *args
      end

      # If Rack::OAuth#get_access_token is nil given the #request_env available
      # (inotherwords, it's nil in our user's current session), then we didn't 
      # log in.  If we have an access token for this particular session, then 
      # we are logged in.
      def logged_in?
        !! oauth.get_access_token(request_env)
      end

      def login_path
        oauth.login_path
      end

    end

    class << self
      attr_accessor :test_mode_enabled
      def enable_test_mode()  self.test_mode_enabled =  true  end
      def disable_test_mode() self.test_mode_enabled =  false end
      def test_mode?()             test_mode_enabled == true  end
    end

    # Returns all of the Rack::OAuth instances found in this Rack 'env' Hash
    def self.all env
      env['rack.oauth']
    end

    # Simple helper to get an instance of Rack::OAuth by name found in this Rack 'env' Hash
    def self.get env, name = 'default'
      all(env)[name.to_s]
    end

    DEFAULT_OPTIONS = {
      :login_path    => '/oauth_login',
      :callback_path => '/oauth_callback',
      :redirect_to   => '/oauth_complete',
      :rack_session  => 'rack.session',
      :json_parser   => lambda {|json_string| require 'json'; JSON.parse(json_string); }
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
      @name   = args.first || 'default'
      
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

    # NEED TO BE ABLE TO OVERRIDE THESE ... these cache access tokens ... these will leak memory like WOW
    #
    # access_token.to_yaml is too big to keep in a cookie session store  :/
    #
    # NOTE: this does NOT work with shotgun because it reloads the class and we lose the instance variables
    def get_access_token env
      if @tokens and session(env)[:token] and session(env)[:secret]
        @tokens[ session(env)[:token] + session(env)[:secret] ]
      end
    end

    def set_access_token env, access_token
      @tokens ||= {}
      @tokens[ session(env)[:token] + session(env)[:secret] ] = access_token
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

    # move this stuff somewhere else that's just related to test stuff?
    def self.mock_response_for method, path
      unless @mock_responses and @mock_responses[path] and @mock_responses[path][method]
        raise "No mock response created for #{ method.inspect } #{ path.inspect }"
      else
        return @mock_responses[path][method]
      end
    end
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
      name == 'default' ? nil : name
    end

  end

  module Auth #:nodoc:

    class OAuth

    end

  end

end
