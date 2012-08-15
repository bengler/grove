class ExternalDocument < ActiveRecord::Migration
  def self.up
    add_column :posts, :document_updated_at, :datetime
    add_column :posts, :external_document_updated_at, :datetime
    add_column :posts, :external_document, :text
    add_column :posts, :conflicted, :boolean, :default => false, :null => false
    add_index  :posts, :conflicted
  end

  def self.down
    remove_column :posts, :document_updated_at
    remove_column :posts, :external_document_updated_at
    remove_column :posts, :external_document
    remove_column :posts, :conflicted
  end
end
