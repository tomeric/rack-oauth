require File.dirname(__FILE__) + '/spec_helper'

describe Rack::OAuth, 'middleware' do
  after do
    Artifice.deactivate
  end

  before do
    Artifice.activate_with(Twitter)
  end

  describe "the rack.oauth session key" do
    def app
      Rack::Builder.new do
        use Rack::Session::Cookie
        use Rack::OAuth, 'twitter', {
          :site            => 'http://twitter.com',
          :consumer_key    => 'banana',
          :consumer_secret => 'captain-crunch'
        }

        run lambda { |env| [200, {}, env['rack.oauth'].inspect] }
      end
    end

    it 'should be accessible from within the Rack application' do
      get '/'

      ['@name="twitter"', '@site="http://twitter.com"',
       '@consumer_key="banana"', '@consumer_secret="captain-crunch"',
       '@sign_in_path="/twitter/sign_in"', '@callback_path="/twitter/callback"',
       '@complete_path="/twitter/complete"', '@rack_session="rack.session"'].each do |value|
        last_response.body.should include(value)
      end
    end
  end

  describe "the Rack::OAuth instance" do
    def app
      Rack::Builder.new do
        use Rack::Session::Cookie
        use Rack::OAuth, 'gmail', {
          :site            => 'http://gmail.com',
          :consumer_key    => 'banana',
          :consumer_secret => 'captain-crunch'
        }

        run lambda { |env| [200, {}, Rack::OAuth.get(env, 'gmail').inspect] }
      end
    end

    it 'should be accessible from within the Rack application' do
      get '/'

      ['@name="gmail"', '@site="http://gmail.com"',
       '@consumer_key="banana"', '@consumer_secret="captain-crunch"',
       '@sign_in_path="/gmail/sign_in"', '@callback_path="/gmail/callback"',
       '@complete_path="/gmail/complete"', '@rack_session="rack.session"'].each do |value|
        last_response.body.should include(value)
      end
    end
  end

  describe "the Rack::OAuth consumer" do
    def app
      Rack::Builder.new do
        use Rack::Session::Cookie
        use Rack::OAuth, 'foursquare', {
          :site            => 'http://foursquare.com',
          :consumer_key    => 'banana',
          :consumer_secret => 'captain-crunch'
        }

        run lambda { |env| [200, {}, Rack::OAuth.get(env, 'foursquare').consumer.inspect] }
      end
    end

    it 'should persist consumer through requests' do
      get '/'
      ['@secret="captain-crunch"', '@key="banana"',
       ':authorize_path=>"/oauth/authorize"', ':request_token_path=>"/oauth/request_token"',
       ':signature_method=>"HMAC-SHA1"', ':access_token_path=>"/oauth/access_token"',
       ':site=>"http://foursquare.com"'].each do |value|
        last_response.body.should include(value)
      end

      get '/'
      ['@secret="captain-crunch"', '@key="banana"',
       ':authorize_path=>"/oauth/authorize"', ':request_token_path=>"/oauth/request_token"',
       ':signature_method=>"HMAC-SHA1"', ':access_token_path=>"/oauth/access_token"',
       ':site=>"http://foursquare.com"'].each do |value|
        last_response.body.should include(value)
      end
    end
  end

  describe 'redirecting to authorize_url' do
    def app
      Rack::Builder.new do
        use Rack::Session::Cookie
        use Rack::OAuth, 'twitter', {
          :site            => 'http://twitter.com',
          :consumer_key    => 'b',
          :consumer_secret => 'c'
        }

        run lambda { |env| [200, {}, "Hello World"] }
      end
    end

    it 'should redirect to authorize_url' do
      get '/twitter/sign_in'

      authorize_url = "http://twitter.com/oauth/authorize?oauth_token=123"
      last_response.headers['Location'].should == authorize_url
    end
  end
end
