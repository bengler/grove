class AddMoreIndexes < ActiveRecord::Migration
  def self.up
    add_index :posts, :klass
    add_index :locations_posts, :location_id
    add_index :group_memberships, :identity_id
    add_index :group_memberships, :group_id
    add_index :group_locations, :group_id
    add_index :group_locations, :location_id
  end

  def self.down
  end
end
