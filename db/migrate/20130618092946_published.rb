class Published < ActiveRecord::Migration
  def self.up
    add_column :posts, :published, :boolean
    add_index :posts, :published
    #connection.execute("UPDATE posts SET published=true")
    #change_column_default(:posts, :published, true)    
  end

  def self.down
    remove_column :posts, :published
  end
end
