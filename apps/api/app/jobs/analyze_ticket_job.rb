# frozen_string_literal: true

# Enqueued by Tickets::ProcessCsv after creating an AiAnalysis record.
# Accepts the analysis UUID (not a GlobalID) because records are created
# via insert_all and no AR instance is available at enqueue time.
# The Ai::AnalyzeTicket service handles atomic claiming, so retries
# are safe — a previously claimed analysis will be skipped.
class AnalyzeTicketJob < ApplicationJob
  queue_as :default

  def perform(ai_analysis_id)
    ai_analysis = AiAnalysis.find(ai_analysis_id)
    Ai::AnalyzeTicket.call(ai_analysis)
  end
end
