# frozen_string_literal: true

class AddRagMetadataToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :embedding_tokens, :integer
    add_column :messages, :retrieval_count, :integer
    add_column :messages, :retrieval_max_similarity, :float
    add_column :messages, :latency_ms, :integer
  end
end
