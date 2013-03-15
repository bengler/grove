class AddTagsIndex < ActiveRecord::Migration
  def self.up
    execute "create index index_posts_on_tags_vector on posts using gist(tags_vector)"
  end

  def self.down
  end
end
