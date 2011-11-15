class GroveV1 < Sinatra::Base
  post "/posts/:uid" do |uid|
    identity_id = current_identity.try(:id)
    halt 403, "No identity" unless identity_id
    @post = Post.find_by_uid(uid) || Post.new(:uid => uid)
    if !current_identity.god? && @post.created_by != identity_id and !@post.new_record?
      halt 403, "Post is owned by a different user (#{@post.created_by})" 
    end
    @post.created_by ||= identity_id
    @post.document = params['document']
    @post.save!
    render :rabl, :post, :format => :json
  end

  get "/posts/:uid" do |uid|
    unless uid =~ /\*/ 
      # Retrieve a single specific post
      @post = Post.find_by_uid(uid)
      halt 404, "No such post" unless @post
      render :rabl, :post, :format => :json
    else
      # Retrieve a collection
      @posts = Post.by_wildcard_uid(uid)
      @posts = @posts.order("created_at desc")
      @limit = (params['limit'] || 20).to_i
      @offset = (params['offset'] || 0).to_i
      @posts = @posts.limit(@limit+1).offset(@offset)
      @last_page = (@posts.size <= @limit)
      @posts = @posts[0..@limit-1]
      render :rabl, :posts, :format => :json      
    end
  end
end