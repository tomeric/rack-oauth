require File.dirname(__FILE__) + '/spec_helper'

require 'sinatra/base'

class App < Sinatra::Base
  use Rack::Session::Cookie
  use Rack::OAuth, 'twitter', {
    :site            => 'http://twitter.com',
    :consumer_key    => '123',
    :consumer_secret => '456'
  }

  helpers do
    include Rack::OAuth::Methods

    def signed_in?
      ! rack_oauth('twitter').nil?
    end
  end

  get '/' do
    if signed_in?
      "Hello World"
    else
      redirect oauth_sign_in_path('twitter')
    end
  end

  get '/get_many' do
    rack_oauth('twitter').inspect
  end

  get '/get_once' do
    rack_oauth!('twitter').inspect
  end

  get '/twitter/complete' do
    info = JSON.parse rack_oauth('twitter').get('/account/verify_credentials.json').body
    info['screen_name']
  end
end

describe 'sinatra app' do
  after do
    Artifice.deactivate
  end

  before do
    Artifice.activate_with(Twitter)
  end

  describe "the Rack::OAuth consumer" do
    def app
      App.new
    end

    it 'should be able to authorize a user' do
      get '/'

      last_response.status.should == 302
      last_response.headers['Location'].should == '/twitter/sign_in'

      get '/twitter/sign_in'
      last_response.status.should == 302

      authorize_path = "http://twitter.com/oauth/authorize?oauth_token=123"
      last_response.headers['Location'].should == authorize_path

      get '/twitter/callback'
      last_response.status.should == 302

      complete_path = "/twitter/complete"
      last_response.headers['Location'].should == complete_path

      get '/'

      last_response.status.should == 200
      last_response.body.should include('Hello World')

      get '/get_many'
      last_response.body.should include('OAuth::AccessToken')
      get '/get_many'
      last_response.body.should include('OAuth::AccessToken')

      get '/get_once'
      last_response.body.should include('OAuth::AccessToken')
      get '/get_once'
      last_response.body.should_not include('OAuth::AccessToken')
    end
  end
end
