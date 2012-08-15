$:.unshift(File.dirname(__FILE__))

require 'config/environment'
require 'api/v1'
require 'rack/contrib'

ENV['RACK_ENV'] ||= 'development'
set :environment, ENV['RACK_ENV'].to_sym

use Rack::CommonLogger

map "/api/grove/v1" do
  use Rack::PostBodyContentTypeParser
  use Rack::MethodOverride
  use Pebbles::Cors
  run GroveV1
end
