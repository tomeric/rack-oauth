require 'rubygems'
require 'rack'
require 'oauth'

module Rack #:nodoc:

  # Rack Middleware for integrating OAuth into your application
  #
  # Note: this *requires* that a Rack::Session middleware be enabled
  #
  class OAuth

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
      :session_key   => 'oauth_user',
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

    # the name of the Session key to use to store user account information (if OAuth completed OK)
    attr_accessor :session_key

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

      @app.call env

      case env['PATH_INFO']
      when login_path;      do_login     env
      when callback_path;   do_callback  env
      else;                 @app.call    env
      end
    end

    def do_login env
      request = consumer.get_request_token :oauth_callback => ::File.join("http://#{ env['HTTP_HOST'] }", callback_path)
      session(env)[:token]  = request.token
      session(env)[:secret] = request.secret
      [ 302, {'Location' => request.authorize_url}, [] ]
    end

    def do_callback env
      session(env)[:verifier] = Rack::Request.new(env).params['oauth_verifier']
      [ 302, { 'Location' => redirect_to }, [] ]
    end

    # Usage:
    #
    #   request :post, '/statuses/update.json', :status => params[:tweet]
    #   request 'GET', '/account/verify_credentials.json'
    #
    # ### request :post, '/statuses/update.json', {}, :status => params[:tweet]
    # ### @cached_consumer.request method, url, @cached_access, *args
    # ### response = consumer.request method, '/account/verify_credentials.json', access, :scheme => :query_string
    def request method, path, *args
      request  = ::OAuth::RequestToken.new consumer, session(env)[:token], session(env)[:secret]
      access   = request.get_access_token :oauth_verifier => session(env)[:verifier]
      
      consumer.request method.to_s.downcase.to_sym, path, access, {}, *args
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
