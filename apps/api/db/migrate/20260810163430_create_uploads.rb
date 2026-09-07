class CreateUploads < ActiveRecord::Migration[8.1]
  def change
    create_table :uploads, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true, index: false
      t.references :uploaded_by, null: true, type: :uuid, foreign_key: { to_table: :users }
      t.string :filename, null: false
      t.string :status, null: false, default: "pending"
      t.integer :total_records
      t.integer :processed_records, default: 0
      t.integer :failed_records, default: 0
      t.timestamps
    end

    add_index :uploads, [ :organization_id, :created_at ], order: { created_at: :desc }
  end
end
