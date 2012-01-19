require "bundler"
Bundler.require

$memcached = Dalli::Client.new

Dir.glob('./lib/**/*.rb').each{ |lib| require lib }

$config = YAML::load(File.open("config/database.yml"))
ENV['RACK_ENV'] ||= "development"
environment = ENV['RACK_ENV']

Hupper.on_initialize do
  ActiveRecord::Base.establish_connection($config[environment])
  $memcached = Dalli::Client.new unless ENV['RACK_ENV'] == 'test'
end

Hupper.on_release do
  ActiveRecord::Base.connection.disconnect!
  $memcached.close
end

Pebblebed.config do
  service :checkpoint
end
