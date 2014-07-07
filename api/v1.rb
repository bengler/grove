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
    LOGGER.info "Processing #{request.url}"
    LOGGER.info "Params: #{params.inspect}"

    # If this service, for some reason lives behind a proxy that rewrites the Cache-Control headers into
    # "must-revalidate" (which IE9, and possibly other IEs, does not respect), these two headers should properly prevent 
    # caching in IE (see http://support.microsoft.com/kb/234067)
    headers 'Pragma' => 'no-cache'
    headers 'Expires' => '-1'

    cache_control :private, :no_cache, :no_store, :must_revalidate
  end

  helpers do

    # Yields the block if the user is allowed to perform the action to the post
    def check_allowed(action, post, &block)
      realm = post.realm || post.canonical_path.split('.').first
      return yield if current_identity.try(:god) && current_identity.realm == realm

      if post.protected_changed?
        halt 403, "You are not allowed to #{action} #{post.uid}. Reason: Only gods may touch the protected field."
      end
      if settings.respond_to?(:disable_callbacks) && settings.disable_callbacks
        return yield if post.may_be_managed_by?(current_identity)
        halt 403, "You are not allowed to #{action} #{post.uid}"
      else
        # Format the post exactly as it would be provided by the http-api
        # (via the petroglyph-view)
        post_as_json = JSON.parse(pg(:post, :locals => {:mypost => post}))
        # Call checkpoint to invoke registered callbacks
        result = pebbles.checkpoint.post("/callbacks/allowed/#{action}/#{post.uid}", post_as_json)
        # Allowed might be true, false or "default"
        case result['allowed']
        when false # categorically denied
          halt 403, "Not allowed to #{action} #{post.uid}. Reason: #{result['reason']}. Denied by: #{result['url']}"
        when true # categorically accepted
          yield
        when 'default' # checkpoint wants us to apply own judgement
          return yield if post.may_be_managed_by?(current_identity)
          halt 403, "You are not allowed to #{action} #{post.uid}"
        else
          halt 500, "Malformed callback response from checkpoint: #{result.unwrap.to_json}"
        end
      end
    end
  end

end
