require File.expand_path('config/site.rb') if File.exists?('config/site.rb')
$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..')))

require "bundler"
Bundler.require

require 'config/logging'

$memcached = Dalli::Client.new

Dir.glob('./lib/**/*.rb').each{ |lib| require lib }

$config = YAML::load(File.open("config/database.yml"))
ENV['RACK_ENV'] ||= "development"
environment = ENV['RACK_ENV']

ActiveRecord::Base.establish_connection($config[environment])
$memcached = Dalli::Client.new unless ENV['RACK_ENV'] == 'test'

Pebblebed.config do
  service :checkpoint
end
