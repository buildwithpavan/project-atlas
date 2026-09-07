# frozen_string_literal: true

# Raised when the AI processing pipeline fails in a non-retryable way.
# Examples: malformed LLM response, missing content, invalid output format.
# Distinct from OpenAI::Errors::APIError which covers provider-level failures.
class AiProcessingError < StandardError; end
