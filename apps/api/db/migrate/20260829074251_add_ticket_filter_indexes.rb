class AddTicketFilterIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # Organization-scoped indexes for ticket filtering.
    # All ticket queries are scoped by organization_id, so composite indexes
    # serve both the filter and the tenant scope in a single index scan.
    add_index :tickets, [:organization_id, :status],  algorithm: :concurrently, name: "index_tickets_on_org_and_status"
    add_index :tickets, [:organization_id, :priority], algorithm: :concurrently, name: "index_tickets_on_org_and_priority"
    add_index :tickets, [:organization_id, :category], algorithm: :concurrently, name: "index_tickets_on_org_and_category"
  end
end
