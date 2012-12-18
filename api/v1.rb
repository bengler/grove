# encoding: utf-8
require "json"
require 'pebblebed/sinatra'
require 'sinatra/petroglyph'

Dir.glob("#{File.dirname(__FILE__)}/v1/**/*.rb").each{ |file| require file }

class GroveV1 < Sinatra::Base
  set :root, "#{File.dirname(__FILE__)}/v1"
  set :protection, :except => :http_origin

  register Sinatra::Pebblebed

  before do
    cache_control :private, :no_cache, :no_store, :must_revalidate
  end

  helpers do

    # Yields the block if the user is allowed to perform the action to the post
    def check_allowed(action, post, &block)
      return yield if post.may_be_managed_by?(current_identity)
      if settings.respond_to?(:disable_callbacks) && settings.disable_callbacks
        halt 403, "You are not allowed to #{action} #{post.uid}"
      end
      # Call checkpoint to invoke registered callbacks
      result = pebbles.checkpoint.get("/callbacks/allowed/#{action}/#{post.uid}")
      p result
      # Allowed might be true, false or "default". If we are here, the user is not allowed by default.
      allowed = result['allowed']
      if allowed == true
        yield
      else
        if allowed == false
          halt 403, "Not allowed to #{action} #{post.uid}. Reason: #{result['reason']}. Denied by: #{result['url']}"
        else
          halt 403, "You are not allowed to #{action} #{post.uid}"
        end
      end
    end
  end

end
