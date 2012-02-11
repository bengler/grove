class Klasspath < ActiveRecord::Migration
  def self.up
    add_column :posts, :klass, :text
  end

  def self.down
  end
end
