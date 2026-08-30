# frozen_string_literal: true

module Ai
  module Providers
    # OpenAI provider using the official Ruby SDK's Responses API with
    # structured outputs. The response is parsed into an Ai::Schemas::TicketAnalysis
    # BaseModel instance, guaranteeing the JSON conforms to the defined schema.
    #
    # Configuration:
    #   ENV["OPENAI_API_KEY"]           - required, raises KeyError if missing
    #   ENV["OPENAI_MODEL"]             - optional, defaults to "gpt-5.6-luna"
    #   ENV["OPENAI_CONNECT_TIMEOUT"]   - connection timeout in seconds (default: 5)
    #   ENV["OPENAI_READ_TIMEOUT"]      - read/request timeout in seconds (default: 30)
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

        def detect_themes(input:)
          response = client.responses.create(
            model: model,
            input: input,
            text: Ai::Schemas::ThemeDetectionOutput
          )

          extract_result(response)
        end

        # Generate embeddings for an array of text strings.
        #
        # Returns an array of embedding vectors in the same input order.
        # Uses the OpenAI embeddings API with explicit dimensions.
        #
        # Options:
        #   model:         embedding model (default: "text-embedding-3-small")
        #   dimensions:    vector dimensions (default: 1536)
        #   include_usage: when true, returns { vectors:, usage: { prompt_tokens: } }
        def embed(texts:, model: "text-embedding-3-small", dimensions: 1536, include_usage: false)
          response = with_retry do
            client.embeddings.create(
              model: model,
              input: texts,
              dimensions: dimensions
            )
          end

          # Sort by index to guarantee input order
          vectors = response.data.sort_by(&:index).map(&:embedding)

          if include_usage
            { vectors: vectors, usage: { prompt_tokens: response.usage&.prompt_tokens } }
          else
            vectors
          end
        end

        # Send a chat completion request.
        #
        # messages: array of { role:, content: } hashes
        # model:    model name (defaults to ENV["OPENAI_MODEL"] / "gpt-5.6-luna")
        #
        # Returns the full ChatCompletion response object.
        def chat(messages:, model: self.model)
          with_retry do
            client.chat.completions.create(
              model: model,
              messages: messages
            )
          end
        end

        # Classify an OpenAI error as retryable or permanent.
        #
        # Retryable: timeouts, rate limits, server errors (5xx).
        # Permanent: authentication, malformed requests, client errors.
        def retryable_error?(error)
          case error
          when OpenAI::Errors::APITimeoutError, OpenAI::Errors::APIConnectionError
            true
          when OpenAI::Errors::RateLimitError, OpenAI::Errors::InternalServerError
            true
          else
            false
          end
        end

        private

        MAX_RETRIES = ENV.fetch("OPENAI_MAX_RETRIES", "2").to_i
        BASE_DELAY = 0.5 # seconds

        # Bounded retry with exponential backoff for transient failures.
        # Only retries errors classified as retryable.
        # Permanent errors are re-raised immediately.
        def with_retry
          attempts = 0
          begin
            attempts += 1
            yield
          rescue OpenAI::Errors::APIError => e
            raise unless retryable_error?(e)
            raise if attempts > MAX_RETRIES

            delay = BASE_DELAY * (2**(attempts - 1))
            Rails.logger.warn(
              "[OpenAI] Retryable error (attempt #{attempts}/#{MAX_RETRIES + 1}): " \
              "#{e.class.name} — retrying in #{delay}s"
            )
            sleep(delay)
            retry
          end
        end

        def client
          OpenAI::Client.new(
            api_key: api_key,
            timeout: {
              connect: connect_timeout,
              read: read_timeout
            }
          )
        end

        def api_key
          ENV.fetch("OPENAI_API_KEY") { raise KeyError, "OPENAI_API_KEY environment variable is not set" }
        end

        def model
          ENV.fetch("OPENAI_MODEL", "gpt-5.6-luna")
        end

        def connect_timeout
          ENV.fetch("OPENAI_CONNECT_TIMEOUT", "5").to_i
        end

        def read_timeout
          ENV.fetch("OPENAI_READ_TIMEOUT", "30").to_i
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
