class LocationsPostsIndex < ActiveRecord::Migration
  def self.up
    add_index :locations_posts, :post_id
  end

  def self.down
  end
end
