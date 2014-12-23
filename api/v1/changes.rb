class GroveV1 < Sinatra::Base

  get "/changes/:uid" do |uid|
    require_identity

    changes = Change.by_uid(uid)
    if (since = params[:since])
      changes = changes.where('changes.id > ?', since.to_i)
    end
    if (limit = params[:limit])
      changes = changes.limit([1000, limit.to_i].min)
    end

    pg :changes, locals: {
      changes: changes.to_a
    }
  end

end