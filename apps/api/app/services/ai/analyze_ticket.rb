# frozen_string_literal: true

module Ai
  class AnalyzeTicket < ApplicationService
    def initialize(ai_analysis)
      @ai_analysis = ai_analysis
    end

    def call
      return unless claim!

      perform_analysis
      complete!
    rescue StandardError, NotImplementedError => e
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
      # Provider integration will be implemented in a future checkpoint.
      # This method will eventually call an AI provider and populate results.
      raise NotImplementedError, "AI provider integration not yet implemented"
    end

    def complete!(attrs = {})
      ai_analysis.update!(
        attrs.merge(status: "completed", processed_at: Time.current)
      )
    end

    def fail_analysis!(message)
      ai_analysis.update!(status: "failed", error_message: message)
    end
  end
end
