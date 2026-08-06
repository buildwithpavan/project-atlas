# frozen_string_literal: true

class NotFoundError < ApplicationError
  def initialize(detail = "Resource not found")
    super(
      title: "Resource Not Found",
      detail: detail,
      status: :not_found,
      type: "/errors/not-found"
    )
  end
end