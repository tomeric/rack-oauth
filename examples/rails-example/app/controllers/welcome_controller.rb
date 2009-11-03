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
    session[:info] = get_access_token.get('/account/verify_credentials.json').body
    redirect_to root_path
  end

end
