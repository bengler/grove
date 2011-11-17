class InitialSchema < ActiveRecord::Migration
  def self.up
    create_table "posts", :force => true do |t|
      t.text "document"
      t.text "realm"
      t.text "box"
      t.text "collection"
      t.text "oid"
      t.column "tags_vector", :tsvector
      t.integer "created_by"
      t.datetime "synced_at"
      t.datetime "created_at"
      t.datetime "updated_at"
    end
    add_index :posts, [:realm, :box, :collection, :oid], :unique => true
    add_index :posts, :created_by
    add_index :posts, :created_at
    add_index :posts, :updated_at
  end

  def self.down
    drop_table :posts
  end
end
