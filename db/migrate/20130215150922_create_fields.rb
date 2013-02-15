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
    execute("create index index_fields_on_text on fields using gin(to_tsvector('simple', text_value))")
  end

  def self.down
  end
end
