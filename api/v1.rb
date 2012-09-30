# encoding: utf-8
require "json"
require 'pebblebed/sinatra'
require 'sinatra/petroglyph'

Dir.glob("#{File.dirname(__FILE__)}/v1/**/*.rb").each{ |file| require file }

class UnauthorizedChangeError < Exception; end

class GroveV1 < Sinatra::Base
  set :root, "#{File.dirname(__FILE__)}/v1"
  set :protection, :except => :http_origin

  register Sinatra::Pebblebed

  before do
    cache_control :private, :no_cache, :no_store, :must_revalidate
  end

end
