require 'simplecov'

SimpleCov.add_filter 'spec'
SimpleCov.add_filter 'config'
SimpleCov.start

$:.unshift(File.dirname(File.dirname(__FILE__)))

ENV["RACK_ENV"] = "test"

require 'bundler'
Bundler.require(:test)

require 'config/environment'

require 'api/v1'

require 'rack/test'
require 'pebblebed/rspec_helper'
require 'timecop'
require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  c.hook_into :webmock 
end

# Set up logging to log/test.log
FileUtils.mkdir_p('log')
LOGGER = Logger.new(File.open('log/test.log', 'a'))
ActiveRecord::Base.logger = LOGGER

set :environment, :test

# Run all examples in a transaction
RSpec.configure do |c|
  c.around(:each) do |example|
    clear_cookies if respond_to?(:clear_cookies)
    $memcached = MemcacheMock.new
    Pebblebed.memcached = $memcached
    ActiveRecord::Base.connection.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end
end
