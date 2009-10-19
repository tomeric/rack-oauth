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
  end

end
