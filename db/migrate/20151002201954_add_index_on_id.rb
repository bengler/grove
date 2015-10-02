class AddIndexOnId < ActiveRecord::Migration

  disable_ddl_transaction!

  def up
    execute "create index concurrently index_posts_on_id_where_visible on posts (id) where not deleted and published"
  end

  def down
    execute "drop index index_posts_on_id_where_visible"
  end

end
