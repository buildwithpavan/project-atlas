# frozen_string_literal: true

# Phase 3K: Add indexes for efficient usage reporting queries and
# a quota reservation column for concurrency-safe quota enforcement.
#
# Usage reporting needs:
#   - organization + month (covered by idx_ai_usage_records_org_created)
#   - organization + model + month
#   - organization + operation + month
#   - organization + user + month (covered by idx_ai_usage_records_org_user, but add created_at)
#   - daily aggregation
#
# Quota reservation:
#   - ai_quota_reserved_tokens on organizations for atomic reservation
class AddUsageQueryIndexesAndQuotaReservation < ActiveRecord::Migration[8.1]
  def change
    # Composite index for model-based usage queries
    add_index :ai_usage_records, [:organization_id, :model, :created_at],
              name: "idx_ai_usage_records_org_model_created",
              order: { created_at: :desc }

    # Composite index for operation-based usage queries
    add_index :ai_usage_records, [:organization_id, :operation, :created_at],
              name: "idx_ai_usage_records_org_operation_created",
              order: { created_at: :desc }

    # Replace org_user index with one that includes created_at for time-scoped queries
    remove_index :ai_usage_records, name: "idx_ai_usage_records_org_user"
    add_index :ai_usage_records, [:organization_id, :user_id, :created_at],
              name: "idx_ai_usage_records_org_user_created",
              order: { created_at: :desc }

    # Daily aggregation index (date truncation uses created_at)
    # The org_created index already covers this, no separate index needed.

    # Atomic reservation counter for concurrency-safe quota enforcement.
    # This is incremented (via UPDATE ... SET col = col + N) before calling OpenAI
    # and decremented on failure. Prevents two concurrent requests from both
    # passing the quota check.
    add_column :organizations, :ai_quota_reserved_tokens, :bigint, default: 0, null: false
  end
end
