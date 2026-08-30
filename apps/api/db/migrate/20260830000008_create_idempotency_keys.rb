# frozen_string_literal: true

class CreateIdempotencyKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :idempotency_keys, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.uuid :user_id, null: false
      t.string :key, null: false
      t.uuid :conversation_id, null: false
      t.string :request_fingerprint, null: false
      t.uuid :user_message_id
      t.uuid :assistant_message_id
      t.jsonb :response_body
      t.integer :response_status
      t.datetime :created_at, null: false

      t.index %i[organization_id user_id key], unique: true, name: "idx_idempotency_keys_unique"
      t.index :created_at, name: "idx_idempotency_keys_created_at"
    end

    add_foreign_key :idempotency_keys, :organizations, column: :organization_id
    add_foreign_key :idempotency_keys, :users, column: :user_id
    add_foreign_key :idempotency_keys, :conversations, column: :conversation_id
    add_foreign_key :idempotency_keys, :messages, column: :user_message_id
    add_foreign_key :idempotency_keys, :messages, column: :assistant_message_id
  end
end
