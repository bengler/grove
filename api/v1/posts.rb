# encoding: utf-8
class GroveV1 < Sinatra::Base

  helpers do

    def filter_visible_posts(posts)
      posts.map{|p| p.visible_to?(current_identity) ? p : nil if p}
    end

    def filter_published(posts, opts={})
      posts.map do |p|
        next nil if p.nil?
        p if opts[:unpublished] == 'include' || p.published
      end
    end

  end

  error TsVectorTags::InvalidTsQueryError do
    [400, "Invalid tags filter"]
  end

  # @apidoc
  # Create or update a post.
  #
  # @note If you specify only some of the post attributes they will be replaced without touching
  #   the other attributes. E.g. specify only 'document' to update attributes without touching
  #   occurrences, tags or paths.
  #
  # @description When creating new posts specify uid without the oid part, (e.g. 'post.event:acme.calendar'),
  #   if you specify the full uid with oid (e.g. 'post.event:acme.calendar$3242') this is considered
  #   an update of the specified document.
  #
  # @category Grove/Posts
  # @path /api/grove/v1/posts/:uid
  # @http POST
  # @example /api/grove/v1/posts/post:acme.invoices
  # @required [String] uid The uid of the post (omitting oid).
  # @required [JSON] post The post to create (see readme for details).
  # @optional [JSON] post[document] The attributes of the post.
  # @optional [JSON] post[tags] Array of tags for the post.
  # @optional [JSON] post[external_id] The external_id of the document.
  # @optional [JSON] post[paths] Array of synonymous paths for the post.
  # @optional [JSON] post[occurrences] Hash of arrays of timestamps for this post.
  #   E.g. {"start_time" => ['2012-11-14T10:54:22+01:00']}
  # @status 204 Success.
  # @status 404 No such post.
  # @status 409 The external_id is in use on a post with a different path.
  # @status 403 Forbidden. This is not your post, and you are not god.

  post "/posts/:uid" do |uid|
    save_post_with_data_race_protection(uid)
  end

  # @apidoc
  # Update a post.
  #
  # @note If you specify only some of the post attributes they will be replaced without touching
  #   the other attributes. E.g. specify only 'document' to update attributes without touching
  #   occurrences, tags or paths.
  #
  # @category Grove/Posts
  # @path /api/grove/v1/posts/:uid
  # @http PUT
  # @example /api/grove/v1/posts/post:acme.invoices
  # @optional [String] uid The uid of the post (omitting oid).
  # @optional [String] external_id The external_id of the post to update.
  # @required [JSON] post The post to create (see readme for details).
  # @optional [JSON] post[document] The attributes of the post.
  # @optional [JSON] post[external_id] The external_id of the document.
  # @optional [JSON] post[tags] Array of tags for the post.
  # @optional [JSON] post[paths] Array of synonymous paths for the post.
  # @optional [JSON] post[occurrences] Hash of arrays of timestamps for this post.
  # @status 204 Success.
  # @status 404 No such post.
  # @status 409 The external_id is in use on a post with a different path.
  # @status 403 Forbidden. This is not your post, and you are not god.

  put "/posts/:uid" do |uid|
    save_post_with_data_race_protection(uid, :only_updates=>true)
  end

  # Will save_post and retry once if a data race gets in our way.
  def save_post_with_data_race_protection(uid, opts={})
    begin
      save_post(uid, opts)
    rescue ActiveRecord::RecordNotUnique => e
      # Handles uniqueness violations in the case of a data-race
      # Reraise unless uniqueness violation
      raise unless e.message =~ /violates.*index_posts_on_realm_and_external_id/
      # Sleep a random amount of time to avoid congestion
      sleep(rand/2)
      # Try again once
      begin
        save_post(uid, opts)
      rescue ActiveRecord::RecordNotUnique => e
        LOGGER.exception(e) if LOGGER.respond_to?(:exception)
        # We failed again. This must be a write storm.
        halt 409, "Unable to resolve data-race. Multiple agents seems to be creating a document with this external_id at this time."
      end
    end
  end

  def save_post(uid, opts={})
    require_identity

    attributes = params[:post]
    halt 400, "No post. Remember to namespace your hashes {\"post\":{\"document\":{...}}" unless attributes

    # If an external_id is submitted this is considered a sync with an external system.
    # external_id must be unique across a single realm. If there is a post with the
    # provided external_id it is updated with the provided content.
    begin
      @post = Post.find_by_external_id_and_uid(attributes[:external_id], uid) if attributes[:external_id]
    rescue Post::CanonicalPathConflict => e
      halt 409, "A post with external_id '#{attributes[:external_id]}' already exists with another canonical path (#{e.message})."
    end

    # If this request is not tagged with an external_id and no oid is provided and you are not a god
    # we protect against double posting.
    if attributes[:external_id].nil? && !current_identity.god? && !(uid =~ /\$.+$/)
      Post.where(:created_by => current_identity.id).
        where("posts.created_at > now() - interval '2 minutes'").by_uid(uid).order('posts.created_at desc').
        each do |post|
        if post.document == attributes['document']
          @post = post # Found a match, proceed as if updating this document
          break
        end
      end
    end

    @post ||= Post.unscoped.find_by_uid(uid)
    @post ||= Post.new(:uid => uid, :created_by => current_identity.id) unless opts[:only_updates]
    halt 404, "Post not found" unless @post

    halt 404, "Post is deleted" if @post.deleted?
    response.status = 201 if @post.new_record?

    allowed_attributes = ['external_document', 'document', 'paths', 'occurrences', 'tags', 'external_id', 'restricted', 'published']
    # Gods have some extra fields they may update
    if current_identity.god?
      allowed_attributes += ['created_at', 'created_by' , 'protected']
    end
    (allowed_attributes & attributes.keys).each do |field|
      @post.send(:"#{field}=", attributes[field])
    end

    check_allowed @post.new_record? ? 'create' : 'update', @post do
      begin
        @post.save!
      rescue Post::CanonicalPathConflict => e
        halt 403, e.message
      end
    end

    pg :post, :locals => {:mypost => @post} # named "mypost" due to https://github.com/kytrinyx/petroglyph/issues/5
  end


  # @apidoc
  # Delete a post.
  #
  # @note By default only the original creator or a god user may delete posts. To override this behavior
  #   you must implement a PSM callback. An uid or an external_id must be specified.
  #
  # @category Grove/Posts
  # @path /api/grove/v1/posts/:uid
  # @http DELETE
  # @example /api/grove/v1/posts/post:acme.invoices$123
  # @optional [String] uid The uid of the post.
  # @optional [String] external_id The external_id of the post.
  # @status 204 Success.
  # @status 404 No such post.
  # @status 403 This is not your post and you are not god!

  delete "/posts/:uid" do |uid|
    require_identity

    if params[:external_id]
      @post = Post.find_by_external_id(params[:external_id])
      halt 404, "No post with external_id #{params[:external_id]}" unless @post
    else
      @post = Post.find_by_uid(uid)
      halt 404, "No post with uid #{uid}" unless @post
    end

    check_allowed :delete, @post do
      @post.deleted = true
      @post.save!
      response.status = 204
    end
  end

  # @apidoc
  # Undelete a post.
  #
  # @note Only gods or members of an accessgroup may undelete posts. Posts lose their external_id when deleted.
  #   Undeleted posts will have their old external_ids stashed in the document under
  #   the key `external_id`.
  # @category Grove/Posts
  # @path /api/grove/v1/posts/:uid/undelete
  # @http POST
  # @example /api/grove/v1/posts/post:acme.invoices$123/undelete
  # @required [String] uid The uid of the post.
  # @status 200 Ok.
  # @status 403 You don't have permission to undelete this post.

  post "/posts/:uid/undelete" do |uid|
    require_identity
    the_post = Post.unscoped.find_by_uid(uid)
    if current_identity.god
      @post = the_post
    else
      @post = Post.unscoped.joins(:locations).
        joins("left outer join group_locations on group_locations.location_id = locations.id").
        joins("left outer join group_memberships on group_memberships.group_id = group_locations.group_id and group_memberships.identity_id = #{current_identity.id}").
        where(['group_memberships.identity_id = ?', current_identity.id]).find_by_uid(uid)
    end
    if !the_post
      halt 404, "No such post"
    elsif @post
        @post.deleted = false
        @post.save!
        response.status = 200
    else
      halt 403, "You don't have permission to undelete this post."
    end
  end

  # To request documents with a specific occurrence an occurrence spec can
  # be provided to the search api. The typical occurrence spec looks something like
  # this:
  #    :occurrence =>
  #      :label => 'start_time',
  #      :from => '2012-1-1',
  #      :order => 'asc'
  def apply_occurrence_scope(scope, spec)
    return scope unless spec
    halt 400, "Occurrence label must be specified" unless spec['label']
    scope = scope.by_occurrence(spec['label'])
    scope = scope.occurs_after(Time.parse(spec['from'])) if spec['from']
    scope = scope.occurs_before(Time.parse(spec['to'])) if spec['to']
    direction = spec['order'].try(:downcase) == 'desc' ? 'DESC' : 'ASC'
    scope = scope.order("occurrence_entries.at #{direction}")
    scope
  end

  # @apidoc
  # Query posts retrieving either a specific post or a collection of posts
  # according to your criteria.
  #
  # @note Due to optimizations, only very basic visibility processing is properly supported when
  #   using comma-separated uids in the query. Generally this should only be used for published, not-deleted
  #   posts with unrestricted visibility.
  #
  # @category Grove/Posts
  # @path /api/grove/v1/posts/:uid
  # @http GET
  # @example /api/grove/v1/posts/post:acme.*?tags=unpaid
  # @optional [String] uid The uid of a specific post, a comma separated list of uids or a wildcard.
  #   uid query (e.g. "*:acme.invoices.*")
  # @optional [Integer] external_id The external_id of the post you want.
  # @optional [String] tags Constrain query by tags. Either a comma separated list of required tags or a
  #   boolean expression like 'paris & !texas' or 'closed & (failed | pending)'.
  # @optional [Integer] created_by Only documents created by this checkpoint identity will be returned.
  # @optional [String] created_after Only documents created after this date (yyyy.mm.dd) will be returned.
  # @optional [String] created_before Only documents created before this date (yyyy.mm.dd) will be returned.
  # @optional [String] unpublished If set to 'include', accessible unpublished posts will be included with the result. If set to 'only', only accessible unpublished posts will be included with the result.
  # @optional [String] deleted If set to 'include', accessible deleted posts will be included with the result.
  # @optional [String] occurrence[label] Require that the post have an occurrence with this label.
  # @optional [String] occurrence[from] The occurrences must be later than this time. Time stamp (ISO 8601).
  # @optional [String] occurrence[to] The occurrences must be earlier than this time. Time stamp (ISO 8601).
  # @optional [String] occurrence[order] 'asc' or 'desc'. The posts will be ordered by their occurrences in
  #   the specified order.
  # @optional [Integer] limit The maximum amount of posts to return.
  # @optional [Integer] offset The index of the first result to return (for pagination).
  # @optional [String] sort_by Name of field to sort by. Defaults to 'created_at'.
  # @optional [String] direction Direction of sort. Defaults to 'desc'.
  # @status 200 JSON.
  # @status 404 No such post.
  # @status 403 Forbidden (the post is restricted, and you are not invited!)

  get "/posts/:uid" do |uid|
    if params[:external_id]
      @post = Post.unscoped.filtered_by(params).find_by_external_id(params[:external_id])
      halt 404, "No such post" unless @post
      halt 403, "Forbidden" unless @post.visible_to?(current_identity)
      pg :post, :locals => {:mypost => @post} # named "mypost" due to https://github.com/kytrinyx/petroglyph/issues/5
    else
      begin
        query = Pebbles::Uid.query(uid)
      rescue ArgumentError => e
        halt 400, e.message
      end
      if query.list?
	      # Retrieve a list of posts.
        # TODO: return to using cached results when we have support for it
        # @posts = filter_visible_posts(Post.cached_find_all_by_uid(query.cache_keys))
        # @posts = filter_published(@posts, :unpublished => params['unpublished'])
        @posts = query.terms.map do |term|
          Post.unscoped.by_uid(term).filtered_by(params).with_restrictions(current_identity).first
        end
        pg :posts, :locals => {:posts => @posts, :pagination => nil}
      elsif query.collection?
      	# Retrieve a collection by wildcards.
        # Temporary hack. It' god damn fugly I know!! TODO: remove this as soon as possible!!!!
        # It's a crisis, which is tried solved otherwise. Alex - please ignore :-)
        if uid.include?("apdm.stream.ba.calendar.*")
          uid = uid.gsub("apdm.stream.ba", "apdm.ba")
          query = Pebbles::Uid.query(uid)
        end
        sort_field = 'created_at'
        if params['sort_by']
          sort_field = params['sort_by'].downcase
          halt 400, "Unknown field #{sort_field}" unless %w(created_at updated_at document_updated_at external_document_updated_at external_document).include? sort_field
        end
        @posts = Post.unscoped.by_uid(uid).with_restrictions(current_identity).filtered_by(params)
        @posts = apply_occurrence_scope(@posts, params['occurrence'])
        direction = (params[:direction] || 'DESC').downcase == 'asc' ? 'ASC' : 'DESC'
        @posts = @posts.order("posts.#{sort_field} #{direction}")
        @posts, @pagination = limit_offset_collection(@posts, :limit => params['limit'], :offset => params['offset'])
        pg :posts, :locals => {:posts => @posts, :pagination => @pagination}
      else
	# Retrieve a single specific post.
        @post = Post.unscoped.by_uid(uid).with_restrictions(current_identity).filtered_by(params).first
        halt 404, "No such post" unless @post
        halt 403, "Forbidden" if !@post.published && !['include', 'only'].include?(params[:unpublished])
        # TODO: Teach .visible_to? about PSM so we can go back to using cached results
        #halt 403, "Forbidden" unless @post.visible_to?(current_identity)
        pg :post, :locals => {:mypost => @post} # named "mypost" due to https://github.com/kytrinyx/petroglyph/issues/5
      end
    end
  end

  # @apidoc
  # Counts the maximum posts that would be returned by a call to GET /api/grove/v1/posts/:uid
  #
  # @category Grove/Posts
  # @path /api/grove/v1/posts/:uid/count
  # @http GET
  # @example /api/grove/v1/posts/post:acme.invoices.*$*/count
  # @optional [String] uid A wildcard uid query (e.g. "*:acme.invoices.*").
  # @optional [String] tags Constrain query by tags. Either a comma separated list of required tags or a
  #   boolean expression like 'paris & !texas' or 'closed & (failed | pending)'.
  # @optional [String] unpublished If set to 'include', accessible unpublished posts will be counted too.
  # @optional [String] deleted If set to 'include', accessible deleted posts will be counted too.
  # @optional [Integer] created_by Only documents created by this checkpoint identity will be counted.
  # @optional [String] created_after Only documents created after this date (yyyy.mm.dd) will be counted.
  # @optional [String] created_before Only documents created before this date (yyyy.mm.dd) will be returned.
  # @optional [Integer] limit The maximum amount of posts to return.
  # @optional [Integer] offset The index of the first result to return (for pagination).
  # @status 200 JSON.
  # @status 404 No such post.
  # @status 403 Forbidden (the post is restricted, and you are not invited!)

  get "/posts/:uid/count" do |uid|
    count_deleted_posts = (params['deleted'] == 'include')
    count = Post.unscoped.by_uid(uid).with_restrictions(current_identity).filtered_by(params).count
    halt 200, {'Content-Type' => 'application/json'}, {:uid => uid, :count => count}.to_json
  end

  # @apidoc
  # Touch a post (updating the updated_at field)
  #
  # @category Grove/Posts
  # @path /api/grove/v1/posts/:uid/touch
  # @http PUT
  # @example /api/grove/v1/posts/post:acme.invoices$123
  # @status 200 JSON.
  # @status 404 No such post.
  # @status 403 Forbidden (This is not your post, and you are not god!)

  put "/posts/:uid/touch" do |uid|
    require_identity

    @post = Post.find_by_uid(uid)
    halt 404, "No such post" unless @post

    check_allowed :update, @post do
      @post.touch
    end
    pg :post, :locals => {:mypost => @post} # named "mypost" due to https://github.com/kytrinyx/petroglyph/issues/5
  end

  # @apidoc
  # Add a synonymous path to the document
  #
  # @category Grove/Posts
  # @path /api/grove/v1/posts/:uid/paths/:path
  # @http POST
  # @required [String] uid The uid of the post.
  # @required [String] path The path to add.
  # @example /api/grove/v1/posts/post:acme.invoices$123/paths/acme.reposession
  # @status 200 JSON.
  # @status 404 No such post.
  # @status 403 Forbidden (This is not your post, and you are not god!)

  post "/posts/:uid/paths/:path" do |uid, path|
    require_identity

    post = Post.find_by_uid(uid)
    halt 404, "No such post" unless post

    check_allowed :update, post do
      post.add_path!(path) unless post.paths.include?(path)
    end

    pg :post, :locals => {:mypost => post}
  end

  # @apidoc
  # Remove a synonymous path to the document
  #
  # @category Grove/Posts
  # @path /api/grove/v1/posts/:uid/paths/:path
  # @http DELETE
  # @required [String] uid The uid of the post.
  # @required [String] path The path to remove.
  # @example /api/grove/v1/posts/post:acme.invoices$123/paths/acme.reposession
  # @status 200 JSON.
  # @status 404 No such post.
  # @status 403 Forbidden (This is not your post, and you are not god!)

  delete "/posts/:uid/paths/:path" do |uid, path|
    require_identity

    post = Post.find_by_uid(uid)
    halt 404, "No such post" unless post

    check_allowed :update, post do
      begin
        post.remove_path!(path)
      rescue Exception => e
        halt 500, e.message
      end
    end
    pg :post, :locals => {:mypost => post}
  end

  # @apidoc
  # Add an occurrence to the post
  #
  # @category Grove/Posts
  # @path /api/grove/v1/posts/:uid/occurrences/:event
  # @http POST
  # @required [String] uid The uid of the post.
  # @required [String] event The kind of occurrence to add (e.g. 'start_time').
  # @required [String] at Time stamp (ISO 8601) to add.
  # @example /api/grove/v1/posts/post:acme.invoices$123/occurrences/start_time?at=2012-11-14T10:54:22+01:00
  # @status 200 JSON.
  # @status 404 No such post.
  # @status 403 Forbidden (This is not your post, and you are not god!)

  post "/posts/:uid/occurrences/:event" do |uid, event|
    require_identity

    post = Post.find_by_uid(uid)
    halt 404, "No such post" unless post

    check_allowed :update, post do
      post.add_occurrences!(event, params[:at])
    end

    pg :post, :locals => {:mypost => post}
  end

  # @apidoc
  # Delete one group of occurrences.
  #
  # @note Will delete every occurrence of the specified kind.
  # @category Grove/Posts
  # @path /api/grove/v1/posts/:uid/occurrences/:event
  # @http DELETE
  # @required [String] uid The uid of the post.
  # @required [String] event The kind of occurrences to delete (e.g. 'start_time').
  # @example /api/grove/v1/posts/post:acme.invoices$123/occurrences/start_time
  # @status 200 JSON.
  # @status 404 No such post.
  # @status 403 Forbidden (This is not your post, and you are not god!)

  delete "/posts/:uid/occurrences/:event" do |uid, event|
    require_identity

    post = Post.find_by_uid(uid)
    halt 404, "No such post" unless post

    check_allowed :update, post do
      post.remove_occurrences!(event)
    end

    response.status = 204
  end

  # @apidoc
  # Replace occurrences in one group with a single occurrence.
  #
  # @category Grove/Posts
  # @path /api/grove/v1/posts/:uid/occurrences/:event
  # @http PUT
  # @required [String] uid The uid of the post.
  # @required [String] event The kind of occurrence to replace (e.g. 'start_time').
  # @required [String] at Time stamp (ISO 8601) to replace any existing occurrences with.
  # @example /api/grove/v1/posts/post:acme.invoices$123/occurrences/start_time?at=2012-11-14T10:54:22+01:00
  # @status 200 JSON.
  # @status 404 No such post.
  # @status 403 Forbidden (This is not your post, and you are not god!)

  put "/posts/:uid/occurrences/:event" do |uid, event|
    require_identity

    post = Post.find_by_uid(uid)
    halt 404, "No such post" unless post

    check_allowed :update, post do
      post.replace_occurrences!(event, params[:at])
    end

    pg :post, :locals => {:mypost => post}
  end

  # @apidoc
  # Add tags to a post
  #
  # @category Grove/Posts
  # @path /api/grove/v1/posts/:uid/tags/:tags
  # @http POST
  # @required [String] uid The uid of the post.
  # @required [String] tags A comma separated list of tags to add.
  # @example /api/grove/v1/posts/post:acme.invoices$123/tags/paris,texas
  # @status 200 JSON.
  # @status 404 No such post.
  # @status 403 Forbidden (This is not your post, and you are not god!)

  post "/posts/:uid/tags/:tags" do |uid, tags|
    require_identity

    @post = Post.find_by_uid(uid)
    halt 404, "No such post" unless @post

    check_allowed :update, @post do
      @post.with_lock do
        @post.tags += params[:tags].split(',')
        @post.save!
      end
    end

    pg :post, :locals => {:mypost => @post}
  end

  # @apidoc
  # Replace tags for a post.
  #
  # @category Grove/Posts
  # @path /api/grove/v1/posts/:uid/tags/:tags
  # @http PUT
  # @required [String] uid The uid of the post.
  # @required [String] tags A comma separated list of tags to set.
  # @example /api/grove/v1/posts/post:acme.invoices$123/tags/paris,texas
  # @status 200 JSON.
  # @status 404 No such post.
  # @status 403 Forbidden (This is not your post, and you are not god!)

  put "/posts/:uid/tags/:tags" do |uid, tags|
    require_identity

    @post = Post.find_by_uid(uid)
    halt 404, "No such post" unless @post

    check_allowed :update, @post do
      @post.with_lock do
        @post.tags = params[:tags]
        @post.save!
      end
    end

    pg :post, :locals => {:mypost => @post}
  end

  # @apidoc
  # Remove tags for a post.
  #
  # @category Grove/Posts
  # @path /api/grove/v1/posts/:uid/tags/:tags
  # @http DELETE
  # @required [String] uid The uid of the post.
  # @required [String] tags A comma separated list of tags to remove.
  # @example /api/grove/v1/posts/post:acme.invoices$123/tags/paris,texas
  # @status 200 JSON.
  # @status 404 No such post.
  # @status 403 Forbidden (This is not your post, and you are not god!)

  delete "/posts/:uid/tags/:tags" do |uid, tags|
    require_identity

    @post = Post.find_by_uid(uid)
    halt 404, "No such post" unless @post

    check_allowed :update, @post do
      @post.with_lock do
        @post.tags -= params[:tags].split(',')
        @post.save!
      end
    end

    pg :post, :locals => {:mypost => @post}
  end
end
