#! /usr/bin/env ruby
%w( rubygems sinatra haml ).each {|lib| require lib }
require File.dirname(__FILE__) + '/../lib/rack-oauth'

use Rack::Session::Cookie

use Rack::OAuth, :site => 'http://twitter.com', :key => '4JjFmhjfZyQ6rdbiql5A', 
                 :secret => 'rv4ZaCgvxVPVjxHIDbMxTGFbIMxUa4KkIdPqL7HmaQo'

helpers do

  # todo ... make wrapper that handles ENV?
  def oauth
    Rack::OAuth.get(env)
  end

end

get '/' do
  haml :index
end

get '/creds' do
  @user = oauth.request(env, '/account/verify_credentials.json') if oauth.verified?(env)
  haml :index
end

get '/oauth_complete' do
  redirect '/'
end

get '/logout' do
  session.clear
  redirect '/'
end

__END__

@@ index

%h1 Twitter OAuth Example

- if @user
  %p User:
  %pre~ @user.to_yaml

%pre~ session.to_yaml
