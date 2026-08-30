# frozen_string_literal: true

# Enqueued by DocumentsController after document creation or reprocessing.
#
# Retry strategy:
#   - Transient errors (OpenAI timeout, network, rate limit) are retried
#     up to 3 times with exponential backoff.
#   - The ProcessDocument service resets the document to pending before
#     re-raising transient errors, so the retry's atomic claim succeeds.
#   - Permanent failures are caught by the service and transition the
#     document to failed — no retry needed.
class ProcessDocumentJob < ApplicationJob
  queue_as :import

  retry_on Net::OpenTimeout,                       wait: :polynomially_longer, attempts: 3
  retry_on Net::ReadTimeout,                       wait: :polynomially_longer, attempts: 3
  retry_on Errno::ECONNREFUSED,                    wait: :polynomially_longer, attempts: 3
  retry_on OpenAI::Errors::APIConnectionError,     wait: :polynomially_longer, attempts: 3
  retry_on OpenAI::Errors::APITimeoutError,        wait: :polynomially_longer, attempts: 3
  retry_on OpenAI::Errors::RateLimitError,         wait: :polynomially_longer, attempts: 3
  retry_on OpenAI::Errors::InternalServerError,    wait: :polynomially_longer, attempts: 3

  def perform(document)
    Documents::ProcessDocument.call(document)
  end
end
