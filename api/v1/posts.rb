class GroveV1 < Sinatra::Base

  post "/posts/:uid" do |uid|
    identity_id = current_identity.try(:id)
    halt 403, "No identity" unless identity_id
    @post = Post.find_by_uid(uid) || Post.new(:uid => uid, :created_by => identity_id)
    response.status = 201 if @post.new_record?

    if !current_identity.god && @post.created_by != identity_id and !@post.new_record?
      halt 403, "Post is owned by a different user (#{@post.created_by})" 
    end

    post = params[:post]
    halt 400, "No post. Remember to namespace your hashes {\"post\":{\"document\":{...}}" unless post
    @post.document = post['document']
    @post.tags = post['tags']
    @post.save!
    pg :post, :locals => {:mypost=>@post} # named "mypost" due to https://github.com/benglerpebbles/petroglyph/issues/5
  end

  delete "/posts/:uid" do |uid|
    identity_id = current_identity.try(:id)
    halt 403, "No identity" unless identity_id
    @post = Post.find_by_uid(uid)
    halt 404, "No such post" unless @post
    if !current_identity.god && @post.created_by != identity_id
      halt 403, "Post is owned by a different user (#{@post.created_by})" 
    end
    @post.destroy
    response.status = 204
  end
  
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

  get "/posts/:uid" do |uid|
    if uid =~ /\,/  
      # Retrieve a list of posts      
      uids = uid.split(/\s*,\s*/).compact
      @posts = Post.cached_find_all_by_uid(uids)
      pg :posts, :locals => {:posts => @posts, :pagination => nil}
    elsif uid =~ /\*/  
      # Retrieve a collection by wildcards
      @posts = Post.by_wildcard_uid(uid)
      @posts = @posts.order("created_at desc")
      @posts = @posts.with_tags(params['tags']) if params['tags']
      @posts, @pagination = limit_offset_collection(@posts, :limit => params['limit'], :offset => params['offset'])
      pg :posts, :locals => {:posts => @posts, :pagination => @pagination}
    else
      # Retrieve a single specific post
      @post = Post.cached_find_all_by_uid([uid]).first
      halt 404, "No such post" unless @post
      pg :post, :locals => {:mypost => @post} # named "mypost" due to https://github.com/benglerpebbles/petroglyph/issues/5
    end
  end
end