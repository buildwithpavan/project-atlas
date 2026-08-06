# frozen_string_literal: true

class ApplicationController < ActionController::API
  rescue_from ApplicationError, with: :render_problem

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
end