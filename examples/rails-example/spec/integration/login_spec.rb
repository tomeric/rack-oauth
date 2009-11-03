require File.dirname(__FILE__) + '/../spec_helper'

Rack::OAuth.enable_test_mode

describe 'Login' do

  it 'should be able to mock a twitter login and web API call' do
    visit root_path
    response.should_not contain('THE_REAL_SHAQ')

    visit login_path # should auto login

    visit root_path
    response.should contain('THE_REAL_SHAQ')
  end

end
