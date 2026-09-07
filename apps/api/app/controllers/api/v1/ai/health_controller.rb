# frozen_string_literal: true

module Api
  module V1
    module Ai
      # AI operational health status.
      #
      # GET /api/v1/ai/health → lightweight status check
      #
      # Returns current AI system status for the authenticated user's
      # organization. Does not call the AI provider.
      class HealthController < BaseController
        include Authenticatable
        include Authorizable
        before_action :authenticate_user!

        def show
          authorize! :read

          result = ::Ai::HealthCheck.call(organization: current_organization)

          render json: {
            data: {
              status: result.status,
              message: result.message,
              configuration_valid: result.configuration_valid,
              checked_at: Time.current.iso8601
            }
          }
        end
      end
    end
  end
end
