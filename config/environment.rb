require "bundler"
Bundler.require

set :root, File.dirname(File.dirname(__FILE__))

$memcached = Dalli::Client.new

Dir.glob('./lib/**/*.rb').each{ |lib| require lib }

$config = YAML::load(File.open("config/database.yml"))
ENV['RACK_ENV'] ||= "development"
environment = ENV['RACK_ENV']
ActiveRecord::Base.establish_connection($config[environment])

Pebbles.config do
  service :checkpoint
end