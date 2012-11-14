class GroveV1 < Sinatra::Base

  # @apidoc
  # Set a readmark
  #
  # @category Grove/Readmarks
  # @path /api/grove/v1/readmarks/:path/:uid
  # @http PUT
  # @example /api/grove/v1/posts/acme.blog/post.blog:acme.blog$123
  # @required [String] path The path the user is currently reading
  # @required [String] uid The uid of the last read post
  # @status 200 Ok

  put "/readmarks/:path/:uid" do |path, uid|
    require_identity

    oid = Pebbles::Uid.oid(uid)
    readmark = Readmark.set!(current_identity.id, path, oid.to_i)
    pg :readmark, :locals => { :readmark => readmark }
  end

  # @apidoc
  # Get readmarks
  #
  # @category Grove/Readmarks
  # @path /api/grove/v1/readmarks/:path
  # @http GET
  # @example /api/grove/v1/posts/acme.*
  # @required [String] path The path we want to check unread counts for. May be a wildcard path to retrieve
  #   a collection of readmarks.
  # @status 200 Ok
  # @status 404 No readmarks for this path

  get "/readmarks/:path" do |path|
    require_identity

    if Pebbles::Uid::Labels.new(path).wildcard?
      pg :readmarks, :locals => { :readmarks => Readmark.where("owner = ?", current_identity.id).by_path(path) }
    else
      # This is a fully constrained path - return exactly one readmark
      readmark = Readmark.where("owner = ?", current_identity.id).by_path(path).first
      halt 404, "No readmark for this path" unless readmark
      pg :readmark, :locals => { :readmark => readmark }
    end
  end
end
