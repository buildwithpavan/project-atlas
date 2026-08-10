class CreateTickets < ActiveRecord::Migration[8.1]
  def change
    create_table :tickets, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true, index: false
      t.references :upload, null: false, type: :uuid, foreign_key: true
      t.string :subject, null: false
      t.text :description
      t.string :customer_name
      t.string :customer_email
      t.string :priority
      t.string :status
      t.string :category
      t.timestamps
    end

    add_index :tickets, [:organization_id, :created_at], order: { created_at: :desc }
  end
end
