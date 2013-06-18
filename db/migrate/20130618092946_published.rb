class Published < ActiveRecord::Migration
  def self.up
    add_column :posts, :published, :boolean, :default => true
    add_index :posts, :published

    connection.execute("UPDATE posts SET published=true")
  end

  def self.down
  end
end
