# frozen_string_literal: true

# Cleans up old AI usage records beyond the retention period.
#
# AiUsageRecords are operational/billing data. Default retention is 12 months.
# Records older than the retention period are deleted in batches to avoid
# locking the table or loading everything into memory.
#
# This job is idempotent and safe to run concurrently (batched DELETE with
# ordered IDs, no table-level locks).
#
# Configuration:
#   AI_USAGE_RETENTION_MONTHS — number of months to retain (default: 12)
#   AI_USAGE_CLEANUP_BATCH_SIZE — records per batch (default: 1000)
class CleanupAiUsageRecordsJob < ApplicationJob
  queue_as :default

  RETENTION_MONTHS = ENV.fetch("AI_USAGE_RETENTION_MONTHS", "12").to_i
  BATCH_SIZE = ENV.fetch("AI_USAGE_CLEANUP_BATCH_SIZE", "1000").to_i

  def perform
    cutoff = RETENTION_MONTHS.months.ago
    total_deleted = 0

    Rails.logger.info("[AiUsageCleanup] Starting cleanup of records older than #{cutoff.iso8601}")

    loop do
      # Select a batch of IDs to delete — avoids loading full records into memory.
      ids = AiUsageRecord.where("created_at < ?", cutoff)
                         .order(:id)
                         .limit(BATCH_SIZE)
                         .pluck(:id)

      break if ids.empty?

      deleted = AiUsageRecord.where(id: ids).delete_all
      total_deleted += deleted

      Rails.logger.info("[AiUsageCleanup] Deleted batch of #{deleted} records (total: #{total_deleted})")

      # Brief pause between batches to reduce database pressure
      sleep(0.1) if deleted == BATCH_SIZE
    end

    Rails.logger.info("[AiUsageCleanup] Completed. Total records deleted: #{total_deleted}")
  end
end
