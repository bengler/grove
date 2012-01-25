class AddExternalId < ActiveRecord::Migration
  def self.up
    add_column :posts, :external_id, :text
    add_index :posts, [:realm, :external_id], :unique => true
  end

  def self.down
  end
end
