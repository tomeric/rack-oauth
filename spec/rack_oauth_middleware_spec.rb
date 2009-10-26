require File.dirname(__FILE__) + '/spec_helper'

# This is just testing to make sure that the basics of the middleware 
# all work.  This does NOT actually test any of the OAuth functionality.
describe Rack::OAuth, 'basic middlware usage' do

  before do
    @app = lambda {|env| [200, {}, ["Hello World"]] }
  end

  it 'should have a name' do
    oauth = Rack::OAuth.new @app, :foo, :site => 'a', :key => 'b', :secret => 'c'
    oauth.name.should == 'foo'
  end

  it 'name should default to "default"' do
    oauth = Rack::OAuth.new @app, :site => 'a', :key => 'b', :secret => 'c'
    oauth.name.should == 'default'
  end

  it 'should be able to access an instance of Rack::OAuth by name from within Rack application' do
    app = lambda {|env| [200, {}, [ env['rack.oauth'].keys.inspect ]] }

    oauth = Rack::OAuth.new app, :foo, :site => 'a', :key => 'b', :secret => 'c'
    RackBox.request(Rack::Session::Cookie.new(oauth), '/').body.should include('foo')
    RackBox.request(Rack::Session::Cookie.new(oauth), '/').body.should_not include('bar')

    oauth = Rack::OAuth.new oauth, :bar, :site => 'a', :key => 'b', :secret => 'c'
    RackBox.request(Rack::Session::Cookie.new(oauth), '/').body.should include('foo')
    RackBox.request(Rack::Session::Cookie.new(oauth), '/').body.should include('bar')
  end

  it 'should be easy to access an instance of Rack::OAuth by name from within Rack application' do
    app = lambda {|env| [200, {}, [ Rack::OAuth.get(env, :bar).inspect ]] }

    oauth = Rack::OAuth.new app, :foo, :site => 'a', :key => 'b', :secret => 'c'
    RackBox.request(Rack::Session::Cookie.new(oauth), '/').body.should == 'nil'

    oauth = Rack::OAuth.new oauth, :bar, :site => 'a', :key => 'b', :secret => 'c'
    RackBox.request(Rack::Session::Cookie.new(oauth), '/').body.should_not == 'nil'
    RackBox.request(Rack::Session::Cookie.new(oauth), '/').body.should include('#<Rack::OAuth')
  end

  it 'should be easy to access to all instances of Rack::OAuth for a Rack application' do
    app = lambda {|env| [200, {}, [ Rack::OAuth.all(env).length ]] }

    oauth = Rack::OAuth.new app, :foo, :site => 'a', :key => 'b', :secret => 'c'
    RackBox.request(Rack::Session::Cookie.new(oauth), '/').body.should == '1'

    oauth = Rack::OAuth.new oauth, :bar, :site => 'a', :key => 'b', :secret => 'c'
    RackBox.request(Rack::Session::Cookie.new(oauth), '/').body.should == '2'

    ## double check it's working as expected ...

    app = lambda {|env| [200, {}, [ Rack::OAuth.all(env).keys ]] }

    oauth = Rack::OAuth.new app, :foo, :site => 'a', :key => 'b', :secret => 'c'
    RackBox.request(Rack::Session::Cookie.new(oauth), '/').body.should     include('foo')
    RackBox.request(Rack::Session::Cookie.new(oauth), '/').body.should_not include('bar')

    oauth = Rack::OAuth.new oauth, :bar, :site => 'a', :key => 'b', :secret => 'c'
    RackBox.request(Rack::Session::Cookie.new(oauth), '/').body.should include('foo')
    RackBox.request(Rack::Session::Cookie.new(oauth), '/').body.should include('bar')
  end

  it 'should be able to get the login path for an instance (so we can easily redirect from the app)' do
    pending
    oauth = Rack::OAuth.new app, :foo, :site => 'a', :key => 'b', :secret => 'c'
    oauth.login_path
    
  end

  # path getters should join the name of the Rack::OAuth.  setters shouldn't include the name.
  it 'login path should be namespaced to the name of the Rack::OAuth instance' do
    app = lambda {|env| [200, {}, [ Rack::OAuth.all(env).keys ]] }

    # the default name doesn't have its name appended.  we assume 'default' for this.
    Rack::OAuth.new(app,       :site => 'a', :key => 'b', :secret => 'c').login_path.should == '/oauth_login'

    Rack::OAuth.new(app, :foo, :site => 'a', :key => 'b', :secret => 'c').login_path.should == '/oauth_login/foo'

    oauth = Rack::OAuth.new(app, :bar, :site => 'a', :key => 'b', :secret => 'c', :login_path => '/twitter_login')
    oauth.login_path.should == '/twitter_login/bar'
  end

  it 'callback path should be namespaced to the name of the Rack::OAuth instance' do
    app = lambda {|env| [200, {}, [ Rack::OAuth.all(env).keys ]] }

    # the default name doesn't have its name appended.  we assume 'default' for this.
    Rack::OAuth.new(app,       :site => 'a', :key => 'b', :secret => 'c').callback_path.should == '/oauth_callback'

    Rack::OAuth.new(app, :foo, :site => 'a', :key => 'b', :secret => 'c').callback_path.should == '/oauth_callback/foo'

    oauth = Rack::OAuth.new(app, :bar, :site => 'a', :key => 'b', :secret => 'c', :callback_path => '/twitter_callback')
    oauth.callback_path.should == '/twitter_callback/bar'
  end

  it 'redirect_to should NOT be namespaced to the name of the Rack::OAuth instance' do
    app = lambda {|env| [200, {}, [ Rack::OAuth.all(env).keys ]] }

    # the default name doesn't have its name appended.  we assume 'default' for this.
    Rack::OAuth.new(app,       :site => 'a', :key => 'b', :secret => 'c').redirect_to.should == '/oauth_complete'

    Rack::OAuth.new(app, :foo, :site => 'a', :key => 'b', :secret => 'c').redirect_to.should == '/oauth_complete'

    oauth = Rack::OAuth.new(app, :bar, :site => 'a', :key => 'b', :secret => 'c', :redirect_to => '/twitter_login_complete')
    oauth.redirect_to.should == '/twitter_login_complete'
  end

  it 'session variables should all be namespaced to the name of the Rack::OAuth instance'

  it 'should explodify with a helpful message if 2 Rack::OAuths are instantiated with the same name (?)'

end
