require File.expand_path('config/site.rb') if File.exists?('config/site.rb')
$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..')))

require "bundler"
Bundler.require

require 'rails/observers/activerecord/base'
require 'rails/observers/activerecord/observer'

$memcached = Dalli::Client.new unless ENV['RACK_ENV'] == 'test'

Dir.glob('./lib/**/*.rb').each{ |lib| require lib }

ENV['RACK_ENV'] ||= "development"
environment = ENV['RACK_ENV']

unless defined?(LOGGER)
  require 'logger'
  LOGGER = Logger.new($stdout)
  LOGGER.level = Logger::INFO
end

Pebblebed.config do
  service :checkpoint
end

ActiveRecord::Base.add_observer RiverNotifications.instance unless environment == 'test'
ActiveRecord::Base.logger = LOGGER
ActiveRecord::Base.configurations = YAML.load(
  ERB.new(File.read(File.expand_path("../database.yml", __FILE__))).result)
ActiveRecord::Base.include_root_in_json = true
ActiveRecord::Base.default_timezone = :local
ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations[environment])
