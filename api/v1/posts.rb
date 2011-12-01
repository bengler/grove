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
    @post.document = post['document']
    @post.tags = post['tags']
    @post.save!
    render :rabl, :post, :format => :json
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
      render :rabl, :posts, :format => :json      
    elsif uid =~ /\*/  
      # Retrieve a collection by wildcards
      @posts = Post.by_wildcard_uid(uid)
      @posts = @posts.order("created_at desc")
      @posts = @posts.with_tags(params['tags']) if params['tags']
      @posts, @pagination = limit_offset_collection(@posts, :limit => params['limit'], :offset => params['offset'])
      render :rabl, :posts, :format => :json      
    else            
      # Retrieve a single specific post
      @post = Post.cached_find_all_by_uid([uid]).first
      halt 404, "No such post" unless @post
      render :rabl, :post, :format => :json
    end
  end
end