class CreateExecutiveSummaries < ActiveRecord::Migration[8.1]
  def change
    create_table :executive_summaries, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid, index: { unique: true }
      t.text :summary, null: false
      t.jsonb :key_findings, null: false, default: []
      t.jsonb :attention_items, null: false, default: []
      t.jsonb :recommended_actions, null: false, default: []
      t.integer :analyzed_ticket_count, null: false
      t.datetime :generated_at, null: false
      t.timestamps
    end
  end
end
