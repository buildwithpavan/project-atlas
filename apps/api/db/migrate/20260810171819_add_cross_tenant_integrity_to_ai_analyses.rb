class AddCrossTenantIntegrityToAiAnalyses < ActiveRecord::Migration[8.1]
  def change
    # Required by PostgreSQL: referenced columns of a composite FK must have a unique constraint
    add_index :tickets, [:organization_id, :id], unique: true, name: "index_tickets_on_organization_id_and_id"

    # Composite FK ensures an AI analysis cannot reference a ticket belonging to a different organization
    add_foreign_key :ai_analyses, :tickets, column: [:organization_id, :ticket_id], primary_key: [:organization_id, :id], name: "fk_ai_analyses_organization_ticket"
  end
end
