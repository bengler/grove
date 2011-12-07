$:.unshift(File.dirname(__FILE__))

require 'config/environment'
require 'api/v1'
require 'config/logging'
require 'rack/contrib'

ENV['RACK_ENV'] ||= 'development'
set :environment, ENV['RACK_ENV'].to_sym

use Rack::CommonLogger

map "/api/grove/v1" do
  use Rack::PostBodyContentTypeParser
  use Rack::MethodOverride
  run GroveV1
end

map '/ping' do
  run lambda { |env| [200, {"Content-Type" => "application/json"}, [{name: "grove"}.to_json]] }
end
