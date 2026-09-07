# frozen_string_literal: true

class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true, index: false
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.string :title
      t.timestamps
    end

    add_index :conversations, [ :organization_id, :user_id, :created_at ], order: { created_at: :desc }, name: "index_conversations_on_org_user_created_at"
    add_index :conversations, [ :organization_id, :id ], unique: true, name: "index_conversations_on_organization_id_and_id"
  end
end
