# frozen_string_literal: true

module Api
  module V1
    class HealthController < BaseController
      def show
        checks = { database: database_healthy? }
        status = checks.values.all? ? :ok : :service_unavailable

        render json: {
          service: "voceive-api",
          version: "v1",
          status: status == :ok ? "healthy" : "degraded",
          checks: checks,
          timestamp: Time.current.iso8601
        }, status: status
      end

      private

      def database_healthy?
        ActiveRecord::Base.connection.execute("SELECT 1")
        true
      rescue StandardError
        false
      end
    end
  end
end
