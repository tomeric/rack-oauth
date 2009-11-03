ENV["RAILS_ENV"] ||= 'test'
require File.dirname(__FILE__) + "/../config/environment" unless defined?(RAILS_ROOT)
require 'spec/autorun'
require 'spec/rails'

Webrat.configure do |config|
  config.mode = :rails
end

Spec::Runner.configure do |config|
  config.include(Webrat::Matchers, :type => [:integration])
end

FakeWeb.allow_net_connect = false

FakeWeb.register_uri :get, 'http://twitter.com/account/verify_credentials.json', :body => %{{"friends_count":190,"utc_offset":-28800,"profile_sidebar_border_color":"829D5E","status":{"in_reply_to_screen_name":null,"text":"Come on people, don't you realize that smoking isn't cool anymore?  Try a healthier stimulant.  Maybe one that doesn't irritate my sinuses?","in_reply_to_user_id":null,"in_reply_to_status_id":null,"source":"web","truncated":false,"favorited":false,"id":5177704516,"created_at":"Mon Oct 26 17:15:10 +0000 2009"},"notifications":false,"statuses_count":1689,"time_zone":"Pacific Time (US & Canada)","verified":false,"profile_text_color":"3E4415","profile_image_url":"http://a3.twimg.com/profile_images/54765389/remi-rock-on_bak_normal.png","profile_background_image_url":"http://s.twimg.com/a/1256577591/images/themes/theme5/bg.gif","location":"Phoenix, AZ","following":false,"favourites_count":0,"profile_link_color":"D02B55","screen_name":"THE_REAL_SHAQ","geo_enabled":false,"profile_background_tile":false,"protected":false,"profile_background_color":"352726","name":"THE_REAL_SHAQ","followers_count":255,"url":"http://remi.org","id":11043342,"created_at":"Tue Dec 11 09:13:43 +0000 2007","profile_sidebar_fill_color":"99CC33","description":"Beer goes in, Code comes out"}}
