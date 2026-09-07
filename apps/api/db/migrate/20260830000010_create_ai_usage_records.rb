# frozen_string_literal: true

class CreateAiUsageRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_usage_records, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.uuid :user_id, null: false
      t.uuid :conversation_id, null: false
      t.uuid :message_id
      t.string :provider, null: false, default: "openai"
      t.string :model, null: false
      t.string :operation, null: false # "chat" or "embedding"
      t.integer :prompt_tokens, default: 0, null: false
      t.integer :completion_tokens, default: 0, null: false
      t.integer :total_tokens, default: 0, null: false
      t.decimal :estimated_cost, precision: 10, scale: 6, default: 0, null: false
      t.string :request_id
      t.integer :latency_ms
      t.datetime :created_at, null: false

      t.index :organization_id, name: "idx_ai_usage_records_org"
      t.index %i[organization_id user_id], name: "idx_ai_usage_records_org_user"
      t.index %i[organization_id created_at], name: "idx_ai_usage_records_org_created",
              order: { created_at: :desc }
      t.index :conversation_id, name: "idx_ai_usage_records_conversation"
      t.index :message_id, name: "idx_ai_usage_records_message"
      t.index :request_id, name: "idx_ai_usage_records_request_id"
    end

    add_foreign_key :ai_usage_records, :organizations, column: :organization_id
    add_foreign_key :ai_usage_records, :users, column: :user_id
    add_foreign_key :ai_usage_records, :conversations, column: :conversation_id
    add_foreign_key :ai_usage_records, :messages, column: :message_id
  end
end
