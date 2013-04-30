class AddLonlat < ActiveRecord::Migration
  def self.up
    add_column :posts, :lon, :float
    add_column :posts, :lat, :float
  end

  def self.down
  end
end
