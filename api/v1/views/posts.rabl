object false
child @posts => :posts do
  attributes :uid, :created_by, :document, :created_at, :updated_at, :tags
end
code :pagination do
  @pagination
end
