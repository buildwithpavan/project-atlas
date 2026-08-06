# frozen_string_literal: true

module Api
  module V1
    class HealthController < BaseController
      def show
        render_success(
          message: "API is healthy",
          data: {
            service: "atlas-api",
            version: "v1",
            timestamp: Time.current.iso8601
          }
        )
      end
    end
  end
end