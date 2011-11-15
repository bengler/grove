$:.unshift(File.dirname(__FILE__))

require 'config/environment'
require 'api/v1'

ENV['RACK_ENV'] ||= 'development'

set :environment, ENV['RACK_ENV'].to_sym

require 'config/logging'

use Rack::CommonLogger

map "/api/grove/v1" do
  run GroveV1
end

test = lambda do |env|
  info = {"ENV['RACK_ENV']" => ENV['RACK_ENV']}
  return [200, {"Content-Type" => "application/json"}, [info.to_json]]
end

map '/test' do
  run test
end

