# frozen_string_literal: true

class ValidationError < ApplicationError
  attr_reader :errors

  def initialize(detail = "Validation failed", errors: nil)
    super(
      title: "Validation Error",
      detail: detail,
      status: :unprocessable_entity,
      type: "/errors/validation"
    )

    @errors = errors
  end
end