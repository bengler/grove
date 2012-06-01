class GroveV1 < Sinatra::Base

  helpers do

    def filter_visible_posts(posts)
      posts.map{|p| p.visible_to?(current_identity) ? p : nil if p}
    end

  end

  post "/posts/:uid" do |uid|
    save_post(uid)
  end

  put "/posts/:uid" do |uid|
    save_post(uid, :only_updates=>true)
  end

  def save_post(uid, opts={})
    require_identity

    attributes = params[:post]
    halt 400, "No post. Remember to namespace your hashes {\"post\":{\"document\":{...}}" unless attributes

    # If an external_id is submitted this is considered a sync with an external system.
    # external_id must be unique across a single realm. If there is a post with the
    # provided external_id it is updated with the provided content.
    begin
      @post = Post.find_by_external_id_and_uid(attributes[:external_id], uid)
    rescue Post::CanonicalPathConflict => e
      halt 409, "A post with external_id '#{attributes[:external_id]}' already exists with another canonical path (#{e.message})."
    end

    @post ||= Post.unscoped.find_by_uid(uid)
    @post ||= Post.new(:uid => uid, :created_by => current_identity.id) unless opts[:only_updates]
    halt 404, "Post not found" unless @post

    halt 404, "Post is deleted" if @post.deleted?
    response.status = 201 if @post.new_record?

    unless @post.may_be_managed_by?(current_identity)
      halt 403, "Post is owned by a different user (#{@post.created_by})"
    end

    (['document', 'paths', 'occurrences', 'tags', 'external_id', 'restricted'] & attributes.keys).each do |field|
      @post.send(:"#{field}=", attributes[field])
    end

    begin
      @post.intercept_and_save!(params[:session])
    rescue UnauthorizedChangeError => e
      halt 403, e.message
    rescue Post::CanonicalPathConflict => e
      halt 403, e.message
    rescue Exception => e
      halt 500, e.message
    end

    pg :post, :locals => {:mypost => @post} # named "mypost" due to https://github.com/benglerpebbles/petroglyph/issues/5
  end

  delete "/posts/:uid" do |uid|
    require_identity

    @post = Post.find_by_uid(uid)
    halt 404, "No such post" unless @post

    unless @post.may_be_managed_by?(current_identity)
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
    klass, path, oid = Pebblebed::Uid.raw_parse(uid)
    if uid =~ /\,/
      # Retrieve a list of posts
      uids = uid.split(/\s*,\s*/).compact
      @posts = filter_visible_posts(Post.cached_find_all_by_uid(uids))
      pg :posts, :locals => {:posts => safe_posts(@posts), :pagination => nil}
    elsif oid == '*' || oid == '' || oid.nil?
      # Retrieve a collection by wildcards
      @posts = Post.by_uid(uid).filtered_by(params).with_restrictions(current_identity)
      direction = (params[:direction] || 'DESC').downcase == 'asc' ? 'ASC' : 'DESC'
      @posts = @posts.order("created_at #{direction}")
      @posts, @pagination = limit_offset_collection(@posts, :limit => params['limit'], :offset => params['offset'])
      pg :posts, :locals => {:posts => safe_posts(@posts), :pagination => @pagination}
    else
      # Retrieve a single specific post
      if uid =~ /[\*\|]/
        @post = Post.by_uid(uid).with_restrictions(current_identity).first
      else
        @post = Post.cached_find_all_by_uid([uid]).first
      end
      halt 404, "No such post" unless @post
      halt 403, "Forbidden" unless @post.visible_to?(current_identity)
      pg :post, :locals => {:mypost => safe_post(@post)} # named "mypost" due to https://github.com/benglerpebbles/petroglyph/issues/5
    end
  end

  get "/posts/:uid/count" do |uid|
    {:uid => uid, :count => Post.by_uid(uid).with_restrictions(current_identity).count}.to_json
  end

  put "/posts/:uid/touch" do |uid|
    require_identity

    @post = Post.find_by_uid(uid)
    halt 404, "No such post" unless @post

    unless @post.may_be_managed_by?(current_identity)
      halt 403, "Post is owned by a different user (#{@post.created_by})"
    end

    @post.touch
    pg :post, :locals => {:mypost => safe_post(@post)} # named "mypost" due to https://github.com/benglerpebbles/petroglyph/issues/5
  end

  post "/posts/:uid/paths/:path" do |uid, path|
    require_identity

    post = Post.find_by_uid(uid)
    halt 404, "No such post" unless post

    post.add_path!(path)

    pg :post, :locals => {:mypost => safe_post(post)}
  end

  delete "/posts/:uid/paths/:path" do |uid, path|
    require_identity

    post = Post.find_by_uid(uid)
    halt 404, "No such post" unless post

    begin
      post.remove_path!(path)
    rescue Exception => e
      halt 500, e.message
    end

    response.status = 204
  end

  post "/posts/:uid/occurrences/:event" do |uid, event|
    require_identity

    post = Post.find_by_uid(uid)
    halt 404, "No such post" unless post

    post.add_occurrences!(event, params[:at])

    pg :post, :locals => {:mypost => safe_post(post)}
  end

  delete "/posts/:uid/occurrences/:event" do |uid, event|
    require_identity

    post = Post.find_by_uid(uid)
    halt 404, "No such post" unless post

    post.remove_occurrences!(event, params[:at])

    response.status = 204
  end

  put "/posts/:uid/occurrences/:event" do |uid, event|
    require_identity

    post = Post.find_by_uid(uid)
    halt 404, "No such post" unless post

    post.replace_occurrences!(event, params[:at])

    pg :post, :locals => {:mypost => safe_post(post)}
  end

  post "/posts/:uid/tags/:tags" do |uid, tags|
    require_identity

    @post = Post.find_by_uid(uid)
    halt 404, "No such post" unless @post

    @post.with_lock do
      @post.tags += params[:tags].split(',')
      @post.save!
    end

    pg :post, :locals => {:mypost => safe_post(@post)}
  end

  put "/posts/:uid/tags/:tags" do |uid, tags|
    require_identity

    @post = Post.find_by_uid(uid)
    halt 404, "No such post" unless @post

    @post.with_lock do
      @post.tags = params[:tags]
      @post.save!
    end

    pg :post, :locals => {:mypost => safe_post(@post)}
  end

  delete "/posts/:uid/tags/:tags" do |uid, tags|
    require_identity

    @post = Post.find_by_uid(uid)
    halt 404, "No such post" unless @post

    @post.with_lock do
      @post.tags -= params[:tags].split(',')
      @post.save!
    end

    pg :post, :locals => {:mypost => safe_post(@post)}
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
    unless current_identity.respond_to?(:god) && current_identity.god
      post.document.delete 'email' if post && !post.document.nil?
    end
    post
  end
end
