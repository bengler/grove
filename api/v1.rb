# encoding: utf-8
require "json"
require 'pebblebed/sinatra'
require 'sinatra/petroglyph'

Dir.glob("#{File.dirname(__FILE__)}/v1/**/*.rb").each{ |file| require file }

class GroveV1 < Sinatra::Base
  set :root, "#{File.dirname(__FILE__)}/v1"
  set :protection, :except => :http_origin

  register Sinatra::ActiveRecordExtension
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

      if post.protected_changed? and not post.new_record?
        realm = post.realm || post.canonical_path.split('.').first
        return yield if current_identity && current_identity.god && current_identity.realm == realm
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

    def limit_offset_collection(collection, options)
      limit = (options[:limit] || 20).to_i
      offset = (options[:offset] || 0).to_i
      collection = collection.limit(limit+1).offset(offset).to_a
      last_page = (collection.size <= limit)
      metadata = {:limit => limit, :offset => offset, :last_page => last_page}
      collection = collection[0..limit-1]
      [collection, metadata]
    end

    # Will save_post and retry once if a data race gets in our way.
    def with_data_race_protection(&block)
      retriable = true
      begin
        return yield
      rescue ActiveRecord::RecordNotUnique => e
        # Handles uniqueness violations in the case of a data-race
        # Reraise unless uniqueness violation
        raise unless e.message =~ /violates.*index_posts_on_realm_and_external_id/
        if retriable
          # Sleep a random amount of time to avoid congestion
          sleep(rand / 2)
          retriable = false
          retry
        end
        message = "Document already exists"
        logger.error(message)
        halt 409, message
      end
    end

    def with_database(uid_or_path, &block)
      if (mappings = database_mappings) && mappings.any?
        if uid_or_path !~ /:/
          path = uid_or_path
        else
          begin
            query = Pebbles::Uid.query(uid_or_path)
          rescue ArgumentError
          else
            if query.list?
              uid_or_path = query.terms.first
            end
          end
          _, path, _ = Pebbles::Uid.parse(uid_or_path) rescue nil
        end
        if path
          _, name = mappings.find { |(k, _)| k == path || path.index("#{k}.") == 0 }
          if name and name != 'default'
            LOGGER.info "Mapping path #{path} to database #{name}"
            return Multidb.use(name, &block)
          end
        end
      end
      return yield
    end

    def database_mappings
      @@database_mappings ||= load_database_mappings
    end

    def load_database_mappings
      mappings = YAML.load(File.read(File.expand_path('../../config/database_mappings.yml', __FILE__))).
        sort_by { |k, v| -k.length }
      LOGGER.info "Loaded mappings: #{mappings.inspect}"
      mappings
    rescue Errno::ENOENT
      {}
    end

  end

  error ActiveRecord::StaleObjectError do |e|
    halt 409, "Post has been modified; refetch and try again"
  end

  error Post::InvalidDataError do |e|
    halt 400, e.message
  end

  error Pebbles::River::ConnectionError do |e|
    logger.error("#{e.class}: #{e.message}")
    halt 503, "Internal connection error"
  end

end
