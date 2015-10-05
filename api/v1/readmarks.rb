class GroveV1 < Sinatra::Base


  # This api is extremely deprecated. Do not use!!

  put "/readmarks/:path/:uid" do |path, uid|
    require_identity

    with_database(uid) do
      oid = Pebbles::Uid.oid(uid)
      readmark = Readmark.set!(current_identity.id, path, oid.to_i)
      pg :readmark, :locals => { :readmark => readmark }
    end
  end

  get "/readmarks/:path" do |path|
    require_identity

    with_database(path) do
      if Pebbles::Uid::Labels.new(path).wildcard?
        pg :readmarks, :locals => { :readmarks => Readmark.where("owner = ?", current_identity.id).by_path(path) }
      else
        # This is a fully constrained path - return exactly one readmark.
        readmark = Readmark.where("owner = ?", current_identity.id).by_path(path).first
        halt 404, "No readmark for this path" unless readmark
        pg :readmark, :locals => { :readmark => readmark }
      end
    end
  end
end
