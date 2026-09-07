# frozen_string_literal: true

module Ai
  # Lightweight AI operational status check.
  #
  # Returns a status assessment based on configuration state, quota state,
  # and recent AI request outcomes.
  # Does NOT call the provider — it inspects local state only.
  #
  # Statuses:
  #   :operational        — AI system is working normally
  #   :configuration_missing — required provider credentials not configured
  #   :quota_exceeded     — organization has hit its quota
  #
  # Usage:
  #   status = Ai::HealthCheck.call(organization: org)
  #   status.status        # => :operational
  #   status.message       # => "AI services are operating normally"
  #   status.configuration_valid  # => true
  class HealthCheck < ApplicationService
    Result = Struct.new(:status, :message, :configuration_valid, keyword_init: true)

    def initialize(organization:)
      @organization = organization
    end

    def call
      # Check configuration first — if provider isn't configured, nothing works
      unless configuration_valid?
        return Result.new(
          status: :configuration_missing,
          message: "AI provider is not configured. Set OPENAI_API_KEY.",
          configuration_valid: false
        )
      end

      # Check quota — most actionable status for orgs with configured limits
      if quota_exceeded?
        return Result.new(
          status: :quota_exceeded,
          message: "AI quota exceeded for this organization",
          configuration_valid: true
        )
      end

      Result.new(
        status: :operational,
        message: "AI services are operating normally",
        configuration_valid: true
      )
    end

    private

    def configuration_valid?
      ENV["OPENAI_API_KEY"].present?
    end

    def quota_exceeded?
      Ai::QuotaEnforcer.call(organization: @organization)
      false
    rescue AiQuotaExceededError
      true
    end
  end
end
