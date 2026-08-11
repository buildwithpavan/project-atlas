# frozen_string_literal: true

class ApplicationController < ActionController::API
  rescue_from ApplicationError, with: :render_problem
  rescue_from ActionController::ParameterMissing, with: :render_parameter_missing

  private

  def render_problem(error)
    response = {
      type: error.type,
      title: error.title,
      status: Rack::Utils.status_code(error.status),
      detail: error.detail
    }

    response[:errors] = error.errors if error.respond_to?(:errors) && error.errors.present?

    render json: response, status: error.status
  end

  def render_parameter_missing(exception)
    render json: {
      type: "/errors/parameter-missing",
      title: "Bad Request",
      status: 400,
      detail: "Required parameter is missing: #{exception.param}"
    }, status: :bad_request
  end
end
