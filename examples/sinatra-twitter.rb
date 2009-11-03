#! /usr/bin/env ruby
%w( rubygems sinatra haml ).each {|lib| require lib }
require File.dirname(__FILE__) + '/../lib/rack-oauth'

use Rack::Session::Cookie

use Rack::OAuth, :site => 'http://twitter.com', :key => '4JjFmhjfZyQ6rdbiql5A', 
                 :secret => 'rv4ZaCgvxVPVjxHIDbMxTGFbIMxUa4KkIdPqL7HmaQo'

helpers do
  include Rack::OAuth::Methods
end

get '/' do
  "home page"
end

get '/creds' do
  info = get_access_token.get '/account/verify_credentials.json'
  info.to_yaml
end

get '/oauth_complete' do
  "oauth complete! ... session: #{ session.to_yaml }"
end

get '/logout' do
  session.clear
  redirect '/'
end
