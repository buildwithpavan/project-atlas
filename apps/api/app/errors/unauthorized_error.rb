# frozen_string_literal: true

class UnauthorizedError < ApplicationError
  def initialize(message = "Unauthorized")
    super(message, status: :unauthorized)
  end
end