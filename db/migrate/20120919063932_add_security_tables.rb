class AddSecurityTables < ActiveRecord::Migration
  def self.up
    create_table :group_memberships do |t|
      t.integer :group_id
      t.integer :identity_id
      t.timestamps
    end
    add_index :group_memberships, [:group_id, :identity_id], :unique => true

    create_table :group_locations do |t|
      t.integer :group_id
      t.integer :location_id
    end
    add_index :group_locations, [:group_id, :location_id], :unique => true
    execute 'alter table group_locations add foreign key (location_id) references locations'
  end

  def self.down
  end
end
