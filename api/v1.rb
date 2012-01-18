# encoding: utf-8
require "json"
require 'pebblebed/sinatra'
require 'sinatra/petroglyph'

Dir.glob("#{File.dirname(__FILE__)}/v1/**/*.rb").each{ |file| require file }

class GroveV1 < Sinatra::Base
  set :root, "#{File.dirname(__FILE__)}/v1"

  register Sinatra::Pebblebed
  i_am :grove


  get '/ping' do
    failures = []

    begin
      ActiveRecord::Base.verify_active_connections!
      ActiveRecord::Base.connection.execute("select 1")
    rescue Exception => e
      failures << "ActiveRecord: #{e.message}"
    end

    begin
      $memcached.get('ping')
    rescue Exception => e
      failures << "Memcached: #{e.message}"
    end

    if failures.empty?
      halt 200, "grove"
    else
      halt 503, failures.join("\n")
    end
  end
end
