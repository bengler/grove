class OccurrenceEntries < ActiveRecord::Migration
  def self.up
    create_table :occurrence_entries do |t|
      t.text :label
      t.integer :post_id
      t.timestamp :at
      t.timestamps
    end
    add_index :occurrence_entries, [:post_id, :label]
    add_index :occurrence_entries, :at
  end

  def self.down
  end
end
