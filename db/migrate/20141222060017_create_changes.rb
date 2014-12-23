class CreateChanges < ActiveRecord::Migration

  def up
    create_table :changes do |t|
      t.timestamp :time, null: false
      t.text :kind, null: false
      t.integer :post_id, null: false
    end
    add_index :changes, :time
    add_index :changes, :post_id
    execute "alter table changes add foreign key (post_id) references posts"
  end

  def down
    drop_table :changes
  end

end
