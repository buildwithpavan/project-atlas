# frozen_string_literal: true

# Recovers records stuck in "processing" due to worker crashes or timeouts.
#
# AI analyses stuck in processing for longer than STALE_THRESHOLD are reset
# to pending and re-enqueued for processing. Uploads stuck in processing
# are marked as failed since their partial state cannot be safely resumed.
#
# Designed to run as a Solid Queue recurring job (see config/recurring.yml).
# Safe to run concurrently — uses atomic UPDATE WHERE to avoid races.
class RecoverStaleJobsJob < ApplicationJob
  queue_as :default

  STALE_THRESHOLD = 10.minutes

  def perform
    recover_stale_analyses
    recover_stale_uploads
    recover_stale_documents
  end

  private

  def recover_stale_analyses
    cutoff = STALE_THRESHOLD.ago

    # Atomic reset — only transitions records still in processing
    reset_ids = AiAnalysis.where(status: "processing")
                          .where("updated_at < ?", cutoff)
                          .pluck(:id)

    return if reset_ids.empty?

    count = AiAnalysis.where(id: reset_ids, status: "processing")
                      .update_all(status: "pending", updated_at: Time.current)

    Rails.logger.info("RecoverStaleJobsJob: reset #{count} stale AI analyses to pending")

    # Re-query for actually-reset records to avoid re-enqueuing wrong IDs
    AiAnalysis.where(id: reset_ids, status: "pending").pluck(:id).each do |id|
      AnalyzeTicketJob.perform_later(id)
    end
  end

  def recover_stale_uploads
    cutoff = STALE_THRESHOLD.ago

    stale_uploads = Upload.where(status: "processing")
                          .where("updated_at < ?", cutoff)

    stale_uploads.find_each do |upload|
      upload.update!(status: "failed", error_message: "Processing timed out — please retry the upload")
      Rails.logger.info("RecoverStaleJobsJob: marked stale upload #{upload.id} as failed")
    end
  end

  def recover_stale_documents
    cutoff = STALE_THRESHOLD.ago

    stale_ids = Document.where(status: "processing")
                        .where("updated_at < ?", cutoff)
                        .pluck(:id)

    return if stale_ids.empty?

    count = Document.where(id: stale_ids, status: "processing")
                    .update_all(status: "pending", updated_at: Time.current)

    Rails.logger.info("RecoverStaleJobsJob: reset #{count} stale documents to pending")

    # Re-query for actually-reset records and safely re-enqueue
    Document.where(id: stale_ids, status: "pending").find_each do |document|
      ProcessDocumentJob.perform_later(document)
    end
  end
end
