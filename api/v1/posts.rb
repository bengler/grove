class GroveV1 < Sinatra::Base
  helpers do
    def generate_random_object_id 
      rand(2**64).to_s(36)
    end
  end

  post "/posts/:uid" do |uid|
    identity_id = current_identity.try(:id)
    halt 403, "No identity" unless identity_id
    klass, path, oid = Pebbles::Uid.parse(uid)
    if oid
      @post = Post.find_by_uid(uid) || Post.new(:uid => uid, :created_by => identity_id)
      response.status = 201 if @post.new_record?
    else
      while @post.nil?
        begin
          @post = Post.create!(:uid => "#{klass}:#{path}$#{generate_random_object_id}", :created_by => identity_id)
          response.status = 201
        rescue ActiveRecord::RecordNotUnique
          # Failed to generate a unique id. Try again, fail better!
        end
      end
    end
    if !current_identity.god? && @post.created_by != identity_id and !@post.new_record?
      halt 403, "Post is owned by a different user (#{@post.created_by})" 
    end
    @post.document = params['document']
    @post.tags = params['tags']
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