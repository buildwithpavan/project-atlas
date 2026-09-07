# frozen_string_literal: true

class UnauthorizedError < ApplicationError
  def initialize(detail = "Unauthorized")
    super(
      title: "Unauthorized",
      detail: detail,
      status: :unauthorized,
      type: "/errors/unauthorized"
    )
  end
end
