require 'rubygems'
require 'spec'
require 'artifice'

Spec::Runner.configure do |config|
  config.include Rack::Test::Methods
end

require File.dirname(__FILE__) + '/../lib/rack-oauth'

Twitter = Rack::Builder.new {
  map '/oauth/request_token' do
    run lambda { |env| [200, {}, 'oauth_token=123&request_secret=456'] }
  end

  map '/oauth/authenticate' do
    run lambda { |env| [200, {}, 'authenticate'] }
  end

  map '/oauth/access_token' do
    run lambda { |env| [200, {}, 'access_token'] }
  end

  map '/account/verify_credentials.json' do
    run lambda { |env| [200, {}, "{ 'screen_name' : 'Croaky' }"] }
  end
}
