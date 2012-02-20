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
    location_map = {}
    counter = 0
    ActiveRecord::Base.connection.execute("SELECT id, realm, box, collection FROM posts").each do |post|
      canonical_path = [post["realm"], post["box"], post["collection"]].join('.')
      ActiveRecord::Base.connection.execute("UPDATE posts SET canonical_path='#{canonical_path}' WHERE id=#{post['id']}")
      location_map[canonical_path] ||= []
      location_map[canonical_path] << post['id']
      counter += 1
      say " ... working" if (counter % 100) == 0
    end
    say " ... Paths for #{counter} posts migrated"
    say "Creating locations and associating posts"
    location_map.each do |canonical_path, post_ids|
      paths = canonical_path.split(".")
      columns = (0..paths.length-1).map {|i| "label_#{i}"}
      values = (0..paths.length-1).map {|i| "'#{paths[i]}'"}
      label_strings = (0..paths.length-1).map {|i| "label_#{i}='#{paths[i]}'"}
      sql = "SELECT id FROM locations where #{label_strings.join(" and ")}"
      location = ActiveRecord::Base.connection.execute(sql).first
      unless location
        say " ... Creating location for #{canonical_path}"
        ActiveRecord::Base.connection.execute("INSERT INTO locations (#{columns.join(", ")}) values (#{values.join(", ")})")
        location = ActiveRecord::Base.connection.execute(sql).first
      end
      say " ... Mapping #{post_ids.count} posts to path #{canonical_path} (location id ##{location['id']})"
      post_ids.each do |post_id|
        ActiveRecord::Base.connection.execute(
          "INSERT INTO locations_posts (location_id, post_id) values (#{location['id']}, #{post_id})")
      end
      say " ... Done"
    end
    remove_column :posts, :box
    remove_column :posts, :collection
    say "Migration complete"
  end

  def self.down
  end
end
