class WelcomeController < ApplicationController

  # GET /
  def index
    if logged_in?
      render :text => "Logged in as #{ session[:info].inspect }"
    else
      render :text => "Not logged in"
    end
  end

  # GET /login
  def login
    redirect_to oauth_login_path
  end

  # GET /oauth_complete
  def after_login
    if oauth_access_token
      session[:info] = oauth_request_with_access_token oauth_access_token, '/account/verify_credentials.json'
    end

    redirect_to root_path
  end

end
