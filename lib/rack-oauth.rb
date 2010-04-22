require 'rubygems'
require 'rack'
require 'oauth'

module Rack #:nodoc:
  # Rack Middleware for integrating OAuth into your application
  #
  # A Rack::Session middleware MUST be enabled.
  class OAuthError < StandardError
  end

  class OAuth
    # Include this module in your Rails controller or Sinatra helpers
    module Methods
      # This is *the* method you want to call.
      # Use it to make GET/POST/PUT/DELETE/HEAD requests of the OAuth Provider.
      def rack_oauth(name)
        oauth_instance(name).get_access_token(oauth_request_env)
      end

      # Same as #rack_oauth but it clears the access token out of the session.
      def rack_oauth!(name)
        oauth_instance(name).get_access_token!(oauth_request_env)
      end

      # [Internal] this method returns the Rack 'env' for the current request.
      #
      # This looks for #env or #request.env by default. If these don't return
      # something, then we raise an exception and you should override this method
      # so it returns the Rack env that we need.
      def oauth_request_env
        if respond_to?(:env)
          env
        elsif respond_to?(:request) && request.respond_to?(:env)
          request.env
        else
          raise Rack::OAuthError, "Couldn't find 'env'. Please override #oauth_request_env."
        end
      end

      # Returns an instance of Rack::OAuth by name.
      def oauth_instance(name)
        instance = Rack::OAuth.get(oauth_request_env, name)
        if instance.nil?
          raise Rack::OAuthError, "Couldn't find Rack::OAuth instance with name #{name}"
        end
        instance
      end

      # Returns the path to sign in via the OAuth Provider.
      def oauth_sign_in_path(name)
        oauth_instance(name).sign_in_path
      end

      # Returns the path after signing in via the OAuth Provider.
      def oauth_complete_path(name)
        oauth_instance(name).complete_path
      end
    end

    def self.get(env, name)
      env['rack.oauth'][name.to_s]
    end

    REQUIRED_OPTIONS = [:consumer_key, :consumer_secret, :site]

    attr_reader :sign_in_path, :callback_path, :complete_path#, authorize_path

    def initialize(app, name, options)
      raise Rack::OAuthError, "#{REQUIRED_OPTIONS.join(',')} are required" unless valid?(options)

      @app  = app
      @name = name.to_s

      @sign_in_path  = options[:sign_in_path]  || "/#{name}/sign_in"
      @callback_path = options[:callback_path] || "/#{name}/callback"
      @complete_path = options[:complete_path] || "/#{name}/complete"
      @rack_session  = options[:rack_session]  || "rack.session"

      options.each {|key, value| self.instance_variable_set(:"@#{key}", value) }
    end

    def call(env)
      env['rack.oauth'] ||= {}
      env['rack.oauth'][@name] = self

      case env['PATH_INFO']
      when @sign_in_path
        # Redirect to the OAuth Provider.
        # When the authorized, the Provider will redirect to callback_path.
        sign_in(env)
      when @callback_path
        # The OAuth Provider has redirected and includes a verifier.
        # We'll use the verifier, our request token, and our request secret
        # to get an access token for this user.
        call_back(env)
      else
        @app.call(env)
      end
    end

    def sign_in(env)
      request = consumer.get_request_token(
        :oauth_callback => "http://#{env['HTTP_HOST']}#{@callback_path}"
      )
      session(env)['request_token']  = request.token
      session(env)['request_secret'] = request.secret

      [302, { 'Content-Type' => 'text/html', 'Location' => request.authorize_url }, []]
    end

    def call_back(env)
      request = ::OAuth::RequestToken.new(consumer,
                                          session(env)['request_token'],
                                          session(env)['request_secret'])
      token = request.get_access_token(:oauth_verifier =>
                                       Rack::Request.new(env).params['oauth_verifier'])
      session(env)['access_token_params'] = token.params

      session(env).delete('request_token')
      session(env).delete('request_secret')

      [302, { 'Content-Type' => 'text/html', 'Location' => complete_path }, []]
    end

    def get_access_token(env)
      params = session(env)['access_token_params']
      ::OAuth::AccessToken.from_hash(consumer, params) if params
    end

    def get_access_token!(env)
      params = session(env).delete('access_token_params')
      ::OAuth::AccessToken.from_hash(consumer, params) if params
    end

    def valid?(options)
      REQUIRED_OPTIONS.all? { |required| options.keys.include?(required) }
    end

    def consumer
      @consumer ||= ::OAuth::Consumer.new(@consumer_key, @consumer_secret, :site => @site)
    end

    def session(env)
      if env[@rack_session].nil?
        message = "env['rack.session'] is nil. " +
                  "Please enable session middleware such as Rack::Session::Cookie. " +
                  "Or, set the :rack_session option to something other than 'rack.session'."
        raise Rack::OAuthError, message
      end
      env[@rack_session]['rack.oauth']        ||= {}
      env[@rack_session]['rack.oauth'][@name] ||= {}
    end
  end
end
