# Be sure to restart your server when you modify this file

# Specifies gem version of Rails to use when vendor/rails is not present
RAILS_GEM_VERSION = '2.3.4' unless defined? RAILS_GEM_VERSION

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

require File.dirname(__FILE__) + '/../../../lib/rack-oauth'

Rails::Initializer.run do |config|
  config.middleware.use Rack::OAuth, :site   => 'http://twitter.com', 
                                     :key    => '4JjFmhjfZyQ6rdbiql5A', 
                                     :secret => 'rv4ZaCgvxVPVjxHIDbMxTGFbIMxUa4KkIdPqL7HmaQo'
  config.time_zone = 'UTC'
end
