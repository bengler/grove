class AddVersionColumnToPosts < ActiveRecord::Migration

  def change
    add_column :posts, :version, :integer, null: false, default: 1
  end

end
