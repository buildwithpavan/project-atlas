# frozen_string_literal: true

class ForbiddenError < ApplicationError
  def initialize(detail = "You do not have permission to perform this action")
    super(
      title: "Forbidden",
      detail: detail,
      status: :forbidden,
      type: "/errors/forbidden"
    )
  end
end
