# frozen_string_literal: true

module Ai
  module Providers
    # OpenAI provider using the official Ruby SDK's Responses API with
    # structured outputs. The response is parsed into an Ai::Schemas::TicketAnalysis
    # BaseModel instance, guaranteeing the JSON conforms to the defined schema.
    #
    # Configuration:
    #   ENV["OPENAI_API_KEY"] - required, raises KeyError if missing
    #   ENV["OPENAI_MODEL"]   - optional, defaults to "gpt-5.6-luna"
    #
    # A new client is instantiated per call to avoid stale connections.
    # Refusal responses from the model are filtered out; if no valid
    # content remains, a RuntimeError is raised.
    class Openai
      SYSTEM_PROMPT = <<~PROMPT
        You are a support ticket analyst. Analyze the given customer support ticket and extract structured insights.

        For each ticket, determine:
        - sentiment: The overall customer sentiment (positive, negative, neutral, or mixed)
        - summary: A concise 1-2 sentence summary of the ticket's core issue or request
        - category: Exactly one of: billing, technical_issue, feature_request, account, onboarding, integrations, performance, general
        - confidence: Your confidence in this analysis from 0.0 to 1.0
        - feature_request: Whether this ticket contains or implies a feature request
        - bug_report: Whether this ticket reports a bug or defect
        - knowledge_gap: Whether this ticket reveals a gap in documentation or user knowledge

        Be precise and objective. Base your analysis only on the ticket content provided.
      PROMPT

      class << self
        def analyze(ticket:)
          response = client.responses.create(
            model: model,
            input: build_input(ticket),
            text: Ai::Schemas::TicketAnalysis
          )

          extract_result(response)
        end

        def generate_executive_summary(input:)
          response = client.responses.create(
            model: model,
            input: input,
            text: Ai::Schemas::ExecutiveSummaryOutput
          )

          extract_result(response)
        end

        private

        def client
          OpenAI::Client.new(api_key: api_key)
        end

        def api_key
          ENV.fetch("OPENAI_API_KEY") { raise KeyError, "OPENAI_API_KEY environment variable is not set" }
        end

        def model
          ENV.fetch("OPENAI_MODEL", "gpt-5.6-luna")
        end

        def build_input(ticket)
          user_content = <<~CONTENT
            Subject: #{ticket.subject}
            Description: #{ticket.description}
          CONTENT

          [
            { role: :system, content: SYSTEM_PROMPT },
            { role: :user, content: user_content }
          ]
        end

        def extract_result(response)
          content = response
            .output
            .flat_map(&:content)
            .grep_v(OpenAI::Models::Responses::ResponseOutputRefusal)
            .first

          raise "No valid response content returned from OpenAI" unless content&.parsed

          content.parsed
        end
      end
    end
  end
end
