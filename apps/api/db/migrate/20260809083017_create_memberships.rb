class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.string :role, null: false

      t.timestamps
    end

    add_index :memberships, [ :user_id, :organization_id ], unique: true
  end
end
