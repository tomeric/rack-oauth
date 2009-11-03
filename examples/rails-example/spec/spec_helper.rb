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
