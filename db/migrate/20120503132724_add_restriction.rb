class AddRestriction < ActiveRecord::Migration

  def self.up
    add_column :posts, :restricted, :boolean, :default => false
    add_index :posts, :restricted
  end

  def self.down
  end

end
