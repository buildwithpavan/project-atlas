# frozen_string_literal: true

module Ai
  # Executes AI analysis on a single ticket via the configured provider.
  #
  # Lifecycle: pending → processing → completed/failed
  #
  # Uses atomic claiming (UPDATE WHERE status=pending) to prevent duplicate
  # processing if AnalyzeTicketJob is retried. The provider response is
  # validated before persisting to ensure sentiment and confidence values
  # are within expected bounds.
  #
  # Error handling:
  #   - Transient errors (network, timeout, rate limit) reset the record to
  #     pending and re-raise so Active Job can retry the job.
  #   - Permanent errors (validation, bad response, unknown provider)
  #     transition the record to failed with a truncated error message.
  class AnalyzeTicket < ApplicationService
    # Transient errors that should be retried at the job level.
    # The record is reset to pending so the retry's atomic claim succeeds.
    TRANSIENT_ERRORS = [
      Ai::Client::ConnectionError,
      Ai::Client::TimeoutError,
      Ai::Client::HttpError,
      Net::OpenTimeout,
      Net::ReadTimeout,
      Errno::ECONNREFUSED
    ].freeze

    def initialize(ai_analysis)
      @ai_analysis = ai_analysis
    end

    def call
      return unless claim!

      perform_analysis
    rescue *TRANSIENT_ERRORS => e
      reset_to_pending!
      raise
    rescue StandardError => e
      fail_analysis!("Analysis failed: #{e.message.truncate(200)}")
    end

    private

    attr_reader :ai_analysis

    def claim!
      rows_affected = AiAnalysis.where(id: ai_analysis.id, status: "pending")
                                .update_all(status: "processing", updated_at: Time.current)
      rows_affected == 1
    end

    def perform_analysis
      ticket = ai_analysis.ticket
      result = provider.analyze(ticket: ticket)
      validate_result!(result)
      complete!(analysis_attributes(result))
    end

    def provider
      name = ENV.fetch("AI_PROVIDER", "openai")
      case name
      when "openai"
        Ai::Providers::Openai
      when "atlas"
        Ai::Providers::Atlas
      else
        raise "Unknown AI provider: #{name.inspect}. Supported: openai, atlas"
      end
    end

    def validate_result!(result)
      unless AiAnalysis::SENTIMENTS.include?(result.sentiment.to_s)
        raise "Invalid sentiment returned: #{result.sentiment}"
      end

      unless AiAnalysis::CATEGORIES.include?(result.category.to_s)
        raise "Invalid category returned: #{result.category}"
      end

      unless result.confidence.between?(0.0, 1.0)
        raise "Confidence out of range: #{result.confidence}"
      end
    end

    def analysis_attributes(result)
      {
        sentiment: result.sentiment.to_s,
        summary: result.summary,
        category: result.category,
        confidence: result.confidence,
        feature_request: result.feature_request,
        bug_report: result.bug_report,
        knowledge_gap: result.knowledge_gap
      }
    end

    def complete!(attrs = {})
      ai_analysis.update!(
        attrs.merge(status: "completed", processed_at: Time.current)
      )
    end

    def fail_analysis!(message)
      ai_analysis.update!(status: "failed", error_message: message)
    end

    # Reset to pending so the job retry's atomic claim can succeed.
    # Uses update_all to avoid validation callbacks and ensure the
    # reset happens even if the record is in an unexpected state.
    def reset_to_pending!
      AiAnalysis.where(id: ai_analysis.id, status: "processing")
                .update_all(status: "pending", updated_at: Time.current)
    end
  end
end
