# frozen_string_literal: true

class CreateThemes < ActiveRecord::Migration[8.1]
  def change
    create_table :themes, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.string :title, null: false
      t.text :description, null: false
      t.string :status, null: false, default: "active"
      t.string :severity, null: false, default: "medium"
      t.integer :ticket_count, null: false, default: 0
      t.text :evidence_summary
      t.text :recommended_action
      t.string :source_batch_id
      t.datetime :first_seen_at
      t.datetime :last_seen_at
      t.timestamps
    end

    add_index :themes, [:organization_id, :status]
    add_index :themes, [:organization_id, :severity]
    add_index :themes, [:organization_id, :ticket_count], order: { ticket_count: :desc }
    add_index :themes, [:organization_id, :last_seen_at], order: { last_seen_at: :desc }

    create_table :theme_memberships, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :theme_id, null: false
      t.uuid :ticket_id, null: false
      t.uuid :organization_id, null: false
      t.decimal :relevance_score, precision: 5, scale: 4
      t.text :evidence_text
      t.datetime :created_at, null: false
    end

    add_index :theme_memberships, [:theme_id, :ticket_id], unique: true, name: "idx_theme_memberships_unique"
    add_index :theme_memberships, [:ticket_id], name: "idx_theme_memberships_ticket"
    add_index :theme_memberships, [:organization_id], name: "idx_theme_memberships_org"
  end
end
