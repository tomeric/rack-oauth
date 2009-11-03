require File.dirname(__FILE__) + '/../spec_helper'

Rack::OAuth.enable_test_mode

describe 'Login' do

  def example_json
    %[{"time_zone":"Pacific Time (US & Canada)","profile_image_url":"http://a3.twimg.com/profile_images/54765389/remi-rock-on_bak_normal.png","description":"Beer goes in, Code comes out","following":false,"profile_text_color":"3E4415","status":{"source":"web","in_reply_to_user_id":64218381,"in_reply_to_status_id":5352275994,"truncated":false,"created_at":"Mon Nov 02 02:00:26 +0000 2009","favorited":false,"in_reply_to_screen_name":"benatkin","id":5352407184,"text":"@benatkin For GoldBar, they would want to tell you when you buy something because lots of people are coming in and not buying anything  :/"},"profile_background_image_url":"http://s.twimg.com/a/1256928834/images/themes/theme5/bg.gif","followers_count":257,"screen_name":"remitaylor","profile_link_color":"D02B55","profile_background_tile":false,"friends_count":190,"url":"http://remi.org","created_at":"Tue Dec 11 09:13:43 +0000 2007","profile_background_color":"352726","notifications":false,"favourites_count":0,"statuses_count":1700,"profile_sidebar_fill_color":"99CC33","protected":false,"geo_enabled":false,"location":"Phoenix, AZ","name":"remitaylor","profile_sidebar_border_color":"829D5E","id":11043342,"verified":false,"utc_offset":-28800}]
  end

  it 'should be able to mock a twitter login and web API call' do
    Rack::OAuth.mock_request '/account/verify_credentials.json', example_json

    visit root_path
    response.should_not contain('remitaylor')

    visit login_path # should auto login

    visit root_path
    response.should contain('remitaylor')
  end

  it 'should be able to mock logging in as a different user'

  it "should be able to get the accesstoken for a user after they've logged in once"

end
