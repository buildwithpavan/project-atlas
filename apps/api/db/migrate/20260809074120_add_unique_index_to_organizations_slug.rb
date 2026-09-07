class AddUniqueIndexToOrganizationsSlug < ActiveRecord::Migration[8.1]
  def change
    add_index :organizations, :slug, unique: true
  end
end
