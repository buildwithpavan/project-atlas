class CreateOrganizations < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :name
      t.string :slug

      t.timestamps
    end
  end
end
