class GroveV1 < Sinatra::Base
  put "/readmarks/:path/:post_uid" do |path, post_uid|
    identity_id = current_identity.try(:id)
    halt 403, "No identity" unless identity_id
    oid = Pebblebed::Uid.new(post_uid).oid
    readmark = Readmark.set!(identity_id, path, oid.to_i)
    pg :readmark, :locals => { :readmark => readmark }
  end

  get "/readmarks/:path" do |path|
    identity_id = current_identity.try(:id)
    halt 403, "No identity" unless identity_id

    if Pebblebed::Uid.wildcard_path?(path)
      pg :readmarks, :locals => { :readmarks => Readmark.where("owner = ?", identity_id).by_path(path) }
    else
      # This is a fully constrained path - return exactly one readmark
      readmark = Readmark.where("owner = ?", identity_id).by_path(path).first
      halt 404, "No readmark for this path" unless readmark
      pg :readmark, :locals => { :readmark => readmark }
    end
  end
end
