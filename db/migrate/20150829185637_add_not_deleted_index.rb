class AddNotDeletedIndex < ActiveRecord::Migration

  def up
    execute "create index index_posts_on_deleted_where_not_deleted on posts (deleted) where not deleted"
  end

  def down
    execute "drop index index_posts_on_deleted_where_not_deleted"
  end

end
