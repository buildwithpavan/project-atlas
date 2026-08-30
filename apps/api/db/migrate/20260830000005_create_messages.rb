# frozen_string_literal: true

class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true, index: true
      t.references :conversation, null: false, type: :uuid, foreign_key: true, index: false
      t.string :role, null: false
      t.text :content, null: false
      t.integer :position, null: false
      t.string :ai_model
      t.integer :input_tokens
      t.integer :output_tokens
      t.jsonb :citations, null: false, default: []
      t.datetime :created_at, null: false
    end

    add_index :messages, [ :conversation_id, :position ], unique: true, name: "index_messages_on_conversation_id_and_position"

    # Composite FK ensures a message cannot reference a conversation belonging to a different organization
    add_foreign_key :messages, :conversations,
      column: [ :organization_id, :conversation_id ],
      primary_key: [ :organization_id, :id ],
      name: "fk_messages_organization_conversation"
  end
end
