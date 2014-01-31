class AddSensitiveField < ActiveRecord::Migration
  def self.up
    add_column :posts, :sensitive, :text
  end

  def self.down
    remove_column :posts, :sensitive
  end
end
