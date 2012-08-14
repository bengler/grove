class ExternalDocument < ActiveRecord::Migration
  def self.up
    add_column :posts, :document_updated_at, :datetime
    add_column :posts, :external_document_updated_at, :datetime
    add_column :posts, :external_document, :text
  end

  def self.down
  end
end
