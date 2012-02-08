$:.unshift(File.dirname(__FILE__))

require 'config/environment'
require 'api/v1'
require 'config/logging'
require 'rack/contrib'

ENV['RACK_ENV'] ||= 'development'
set :environment, ENV['RACK_ENV'].to_sym

use Rack::CommonLogger

Pingable.active_record_checks!

Pingable.add_check lambda {
  begin
    $memcached.get('ping')
    nil
  rescue Exception => e
    "Memcached: #{e.message}"
  end
}

map "/api/grove/v1/ping" do
  use Pingable::Handler, "grove"
end

map "/api/grove/v1" do
  use Rack::PostBodyContentTypeParser
  use Rack::MethodOverride
  run GroveV1
end
