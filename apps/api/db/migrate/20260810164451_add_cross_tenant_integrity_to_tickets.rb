class AddCrossTenantIntegrityToTickets < ActiveRecord::Migration[8.1]
  def change
    # Required by PostgreSQL: referenced columns of a composite FK must have a unique constraint
    add_index :uploads, [:organization_id, :id], unique: true, name: "index_uploads_on_organization_id_and_id"

    # Composite FK ensures a ticket cannot reference an upload belonging to a different organization
    add_foreign_key :tickets, :uploads, column: [:organization_id, :upload_id], primary_key: [:organization_id, :id], name: "fk_tickets_organization_upload"
  end
end
