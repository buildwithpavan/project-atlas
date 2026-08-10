class CreateAiAnalyses < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_analyses, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true, index: false
      t.references :ticket, null: false, type: :uuid, foreign_key: true, index: { unique: true }
      t.string :status, null: false, default: "pending"
      t.string :sentiment
      t.text :summary
      t.string :category
      t.decimal :confidence, precision: 5, scale: 4
      t.boolean :feature_request
      t.boolean :bug_report
      t.boolean :knowledge_gap
      t.text :error_message
      t.datetime :processed_at
      t.timestamps
    end

    add_index :ai_analyses, [ :organization_id, :created_at ], order: { created_at: :desc }
    add_index :ai_analyses, [ :status ], where: "status IN ('pending', 'processing')", name: "index_ai_analyses_on_status_partial"
  end
end
