object false
child @posts => :posts do
  attributes :uid, :created_by, :document, :created_at, :updated_at
 end
code :pagination do
  {:limit => @limit, :offset => @offset} 
end
