class SetNotNullOnPostsPublished < ActiveRecord::Migration
  def self.up
    connection.execute("UPDATE posts SET published = true WHERE published is null")
    change_column :posts, :published, :boolean, :null => false, :default => true
  end

  def self.down
  end
end
