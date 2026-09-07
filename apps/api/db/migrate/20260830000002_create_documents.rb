# frozen_string_literal: true

class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true, index: false
      t.references :uploaded_by, null: true, type: :uuid, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.string :filename, null: false
      t.string :content_type, null: false
      t.integer :file_size, null: false
      t.string :status, null: false, default: "pending"
      t.string :checksum
      t.text :extracted_text
      t.integer :chunk_count, null: false, default: 0
      t.string :embedding_model
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :documents, [ :organization_id, :created_at ], order: { created_at: :desc }
    add_index :documents, [ :organization_id, :checksum ], unique: true, name: "index_documents_on_organization_id_and_checksum"
    add_index :documents, [ :organization_id, :id ], unique: true, name: "index_documents_on_organization_id_and_id"
  end
end
