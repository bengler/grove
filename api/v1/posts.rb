class GroveV1 < Sinatra::Base

  helpers do
    def limit_offset_collection(collection, options)
      limit = (options[:limit] || 20).to_i
      offset = (options[:offset] || 0).to_i
      collection = collection.limit(limit+1).offset(offset)
      last_page = (collection.size <= limit)
      metadata = {:limit => limit, :offset => offset, :last_page => last_page}
      collection = collection[0..limit-1]
      [collection, metadata]
    end
  end

  post "/posts/:uid" do |uid|
    identity_id = current_identity.try(:id)
    halt 403, "No identity" unless identity_id

    # If an external_id is submitted this is considered a sync with an external system.
    # external_id must be unique across a single realm. If there is a post with the
    # provided external_id it is updated with the provided content.

    external_id = params[:post][:external_id]
    if external_id
      realm = Pebblebed::Uid.new(uid).realm
      @post = Post.unscoped.find_by_realm_and_external_id(realm, external_id)
      if @post
        @post.deleted = false
        existing_path = Pebblebed::Uid.new(@post.uid).path
        provided_path = Pebblebed::Uid.new(uid).path
        if existing_path != provided_path
          halt 409, "Unable to create. A post with external_id '#{params[:post][:external_id]}' is allready posted with another canonical path (#{@post.uid})."
        end
      end
    end

    @post ||= Post.find_by_uid(uid) || Post.new(:uid => uid, :created_by => identity_id)
    response.status = 201 if @post.new_record?

    if !current_identity.god && @post.created_by != identity_id and !@post.new_record?
      halt 403, "Post is owned by a different user (#{@post.created_by})"
    end

    post = params[:post]

    halt 400, "No post. Remember to namespace your hashes {\"post\":{\"document\":{...}}" unless post

    (['document', 'paths', 'occurrences', 'tags', 'external_id'] & post.keys).each do |field|
      @post.send(:"#{field}=", post[field])
    end
    @post.save!

    pg :post, :locals => {:mypost => @post} # named "mypost" due to https://github.com/benglerpebbles/petroglyph/issues/5
  end

  delete "/posts/:uid" do |uid|
    identity_id = current_identity.try(:id)
    halt 403, "No identity" unless identity_id
    @post = Post.find_by_uid(uid)
    halt 404, "No such post" unless @post
    if !current_identity.god && @post.created_by != identity_id
      halt 403, "Post is owned by a different user (#{@post.created_by})"
    end
    @post.deleted = true
    @post.save!
    response.status = 204
  end

  post "/posts/:uid/undelete" do |uid|
    halt 403, "Only gods may undelete" unless current_identity.god
    @post = Post.unscoped.find_by_uid(uid)
    @post.deleted = false
    @post.save!
    [200, "Ok"]
  end

  get "/posts/:uid" do |uid|
    if uid =~ /\,/
      # Retrieve a list of posts
      uids = uid.split(/\s*,\s*/).compact
      @posts = Post.cached_find_all_by_uid(uids)
      pg :posts, :locals => {:posts => safe_posts(@posts), :pagination => nil}
    elsif uid =~ /[\*\|]/
      # Retrieve a collection by wildcards
      @posts = Post.by_uid(uid)
      @posts = @posts.order("created_at desc")
      @posts = @posts.where("klass in (?)", params['klass'].split(',').map(&:strip)) if params['klass']
      @posts = @posts.with_tags(params['tags']) if params['tags']
      @posts = @posts.where("created_by = ?", params['created_by']) if params['created_by']
      @posts, @pagination = limit_offset_collection(@posts, :limit => params['limit'], :offset => params['offset'])
      pg :posts, :locals => {:posts => safe_posts(@posts), :pagination => @pagination}
    else
      # Retrieve a single specific post
      @post = Post.cached_find_all_by_uid([uid]).first
      Log.error @post.inspect
      halt 404, "No such post" unless @post
      pg :post, :locals => {:mypost => safe_post(@post)} # named "mypost" due to https://github.com/benglerpebbles/petroglyph/issues/5
    end
  end

  get "/posts/:uid/count" do |uid|
    {:uid => uid, :count => Post.by_uid(uid).count}.to_json
  end

  # Get current identity's posts for a given path
  get '/posts' do
    require_identity
    path = params[:path]
    halt 500, "Please specify path parameter" unless path
    scope = Post.by_uid "post:#{path}"
    scope = scope.where('created_by = ?', current_identity.id)
    @posts, @pagination = limit_offset_collection(scope, :limit => params['limit'], :offset => params['offset'])
    response.status = 200
    pg :posts, :locals => {:posts => safe_posts(@posts), :pagination => @pagination}
  end

  ### TODO: HACK ALERT for DittForslag: Avoid leaking e-mail addresses
  private
  def safe_posts(posts)
    posts.map {|p| safe_post(p)}
  end
  def safe_post(post)
    unless current_identity.try(:god)
      post.document.delete 'email' if post && !post.document.nil?
    end
    post
  end
end
