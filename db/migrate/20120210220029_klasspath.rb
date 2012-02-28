class Klasspath < ActiveRecord::Migration
  def self.up
    add_column :posts, :klass, :text
    ActiveRecord::Base.connection.execute("UPDATE posts SET klass='post'")
  end

  def self.down
  end
end
