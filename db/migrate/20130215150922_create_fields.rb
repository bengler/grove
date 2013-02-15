class CreateFields < ActiveRecord::Migration
  def self.up
    create_table :fields do |t|
      t.integer :post_id
      t.text :key
      t.integer :native_type
      t.text :text_value
      t.integer :integer_value
      t.timestamp :time_value
      t.timestamps
    end
    add_index :fields, [:post_id, :key], :unique => true
    add_index :fields, :text_value
    add_index :fields, :integer_value
    add_index :fields, :time_value
    add_index :fields, :native_type
    execute("create index index_fields_on_text on fields using gin(to_tsvector('simple', text_value))")

    count = Post.count
    i = 0
    Post.find_each do |post|
      post.send(:resync_fields)
      i += 1
      puts "#{i}/#{count}" if i % 100 == 0
    end
  end

  def self.down
  end
end
