# encoding: utf-8
require "json"

Dir.glob("#{File.dirname(__FILE__)}/v1/**/*.rb").each{ |file| require file }

class GroveV1 < Sinatra::Base
  Rabl.register!

  error ActiveRecord::RecordNotFound do
    halt 404, "Record not found"
  end

  helpers do
    def checkpoint_session
      params[:session] || request.cookies['checkpoint.session']
    end

    def pebbles
      @pebbles ||= Pebbles::Connector.new(checkpoint_session, :host => request.host)
    end

    def current_identity
      pebbles.checkpoint.me
    end

  end

end
