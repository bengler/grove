class AddProtectedToPost < ActiveRecord::Migration
  def self.up
    add_column :posts, :protected, :text
  end

  def self.down
    remove_column :posts, :protected
  end
end
