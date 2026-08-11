# frozen_string_literal: true

# Base error class for API errors, rendered as RFC 9457 Problem Details
# by ApplicationController#render_problem. Subclasses define specific
# HTTP status codes, problem type URIs, and human-readable titles.
class ApplicationError < StandardError
  attr_reader :status, :type, :title, :detail

  def initialize(title:, detail:, status:, type: "about:blank")
    super(detail)

    @title = title
    @detail = detail
    @status = status
    @type = type
  end
end
