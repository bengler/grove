class Paths < ActiveRecord::Migration
  def self.up
    create_table :locations do |t|
      t.text :label_0
      t.text :label_1
      t.text :label_2
      t.text :label_3
      t.text :label_4
      t.text :label_5
      t.text :label_6
      t.text :label_7
      t.text :label_8
      t.text :label_9
      t.timestamps
    end
    add_index :locations, 
      [:label_0, :label_1, :label_2, :label_3, 
       :label_4, :label_5, :label_6, :label_7, 
       :label_8, :label_9], :unique => true, :name => 'index_locations_on_labels'

    create_table :locations_posts, :id => false do |t|
      t.references :location, :null => false
      t.references :post, :null => false
    end
    add_index :locations_posts, [:location_id, :post_id], :unique => true

    add_column :posts, :canonical_path, :text
    
    say "Migrating paths"
    Post.find_in_batches(:batch_size => 200) do |posts|
      posts.each do |post|
        post.canonical_path = [post.realm, post.box, post.collection].join('.')
      end
      say " ... working"
    end

    remove_column :posts, :box
    remove_column :posts, :collection
  end

  def self.down
  end
end
