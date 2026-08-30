# frozen_string_literal: true

module Ai
  # Centralized pricing lookup for AI model cost estimation.
  #
  # Prices are per token. The source is OpenAI's published pricing
  # as of 2026-08. Update this table when models or prices change.
  #
  # Returns estimated_cost — not authoritative billing data.
  class ModelPricing
    # Pricing per token (USD). Input = prompt tokens, Output = completion tokens.
    PRICING = {
      "gpt-5.6-luna" => { input: 0.000005, output: 0.000015 },
      "gpt-4o" => { input: 0.0000025, output: 0.000010 },
      "gpt-4o-mini" => { input: 0.00000015, output: 0.0000006 },
      "text-embedding-3-small" => { input: 0.00000002, output: 0.0 },
      "text-embedding-3-large" => { input: 0.00000013, output: 0.0 }
    }.freeze

    UNKNOWN_MODEL_RATE = { input: 0.0, output: 0.0 }.freeze

    class << self
      def estimate(model:, prompt_tokens: 0, completion_tokens: 0)
        rates = PRICING.fetch(model) do
          Rails.logger.warn("[ModelPricing] Unknown model '#{model}' — using zero-cost fallback")
          UNKNOWN_MODEL_RATE
        end
        input_cost = (prompt_tokens || 0) * rates[:input]
        output_cost = (completion_tokens || 0) * rates[:output]
        (input_cost + output_cost).round(6)
      end

      def supported_model?(model)
        PRICING.key?(model)
      end

      def supported_models
        PRICING.keys
      end
    end
  end
end
