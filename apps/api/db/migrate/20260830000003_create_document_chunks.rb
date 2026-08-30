# frozen_string_literal: true

class CreateDocumentChunks < ActiveRecord::Migration[8.1]
  def change
    create_table :document_chunks, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true, index: true
      t.references :document, null: false, type: :uuid, foreign_key: true, index: false
      t.text :content, null: false
      t.integer :position, null: false
      t.integer :token_count
      t.column :embedding, :vector, limit: 1536
      t.jsonb :metadata, null: false, default: {}
      t.datetime :created_at, null: false
    end

    add_index :document_chunks, [ :document_id, :position ], unique: true, name: "index_document_chunks_on_document_id_and_position"

    # Composite FK ensures a chunk cannot reference a document belonging to a different organization
    add_foreign_key :document_chunks, :documents,
      column: [ :organization_id, :document_id ],
      primary_key: [ :organization_id, :id ],
      name: "fk_document_chunks_organization_document"
  end
end
