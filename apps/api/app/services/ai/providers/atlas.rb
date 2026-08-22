# frozen_string_literal: true

require "ostruct"

module Ai
  module Providers
    # Atlas provider that routes ticket analysis through the FastAPI AI service
    # instead of calling OpenAI directly. Uses Ai::Client for HTTP transport.
    #
    # Returns an OpenStruct matching the interface expected by Ai::AnalyzeTicket:
    #   - sentiment, summary, category, confidence
    #   - feature_request, bug_report, knowledge_gap
    class Atlas
      class << self
        def analyze(ticket:)
          payload = {
            ticket_id: ticket.id.to_s,
            subject: ticket.subject,
            description: ticket.description.to_s
          }

          response = client.post("/v1/analyze/ticket", payload)
          map_response(response)
        end

        private

        def client
          Ai::Client.new
        end

        def map_response(data)
          OpenStruct.new(
            sentiment: data["sentiment"],
            summary: data["summary"],
            category: data["category"],
            confidence: data["confidence"].to_f,
            feature_request: !!data["feature_request"],
            bug_report: !!data["bug_report"],
            knowledge_gap: !!data.fetch("knowledge_gap", false)
          )
        end
      end
    end
  end
end
