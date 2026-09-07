# frozen_string_literal: true

# Raised when an organization has exceeded its AI usage quota.
# Handled by the controller to return a 429-style response.
class AiQuotaExceededError < StandardError
  attr_reader :limit_type, :current_value, :limit_value

  def initialize(limit_type:, current_value:, limit_value:)
    @limit_type = limit_type
    @current_value = current_value
    @limit_value = limit_value
    super("AI #{limit_type} quota exceeded: #{current_value}/#{limit_value}")
  end
end
