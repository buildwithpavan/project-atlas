# frozen_string_literal: true

# Enqueued by Tickets::ProcessCsv after creating an AiAnalysis record.
# Accepts the analysis UUID (not a GlobalID) because records are created
# via insert_all and no AR instance is available at enqueue time.
#
# Retry strategy:
#   - Transient AI service errors (network, timeout, rate limit) are retried
#     up to 3 times with exponential backoff (~30s, ~60s, ~120s).
#   - The Ai::AnalyzeTicket service resets the record to pending before
#     re-raising transient errors, so the retry's atomic claim succeeds.
#   - Permanent failures (validation, bad response) are caught by the
#     service and transition the record to failed — no retry needed.
class AnalyzeTicketJob < ApplicationJob
  queue_as :analysis

  retry_on Ai::Client::ConnectionError, wait: :polynomially_longer, attempts: 3
  retry_on Ai::Client::TimeoutError,    wait: :polynomially_longer, attempts: 3
  retry_on Ai::Client::HttpError,       wait: :polynomially_longer, attempts: 3
  retry_on Net::OpenTimeout,            wait: :polynomially_longer, attempts: 3
  retry_on Net::ReadTimeout,            wait: :polynomially_longer, attempts: 3
  retry_on Errno::ECONNREFUSED,         wait: :polynomially_longer, attempts: 3

  def perform(ai_analysis_id)
    ai_analysis = AiAnalysis.find(ai_analysis_id)
    Ai::AnalyzeTicket.call(ai_analysis)
  end
end
