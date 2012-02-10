class OccurenceEntries < ActiveRecord::Migration
  def self.up
    create_table :occurence_entries do |t|
      t.text :label
      t.integer :post_id
      t.timestamp :at
      t.timestamps
    end
    add_index :occurence_entries, [:post_id, :label]
    add_index :occurence_entries, :at
  end

  def self.down
  end
end
