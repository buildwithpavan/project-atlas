# frozen_string_literal: true

class AddConversationToIdempotencyKeysUniqueIndex < ActiveRecord::Migration[8.1]
  def change
    remove_index :idempotency_keys, name: "idx_idempotency_keys_unique"
    add_index :idempotency_keys, %i[organization_id user_id conversation_id key],
              unique: true, name: "idx_idempotency_keys_unique"
  end
end
