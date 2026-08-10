# frozen_string_literal: true

module Ai
  class AnalyzeTicket < ApplicationService
    def initialize(ai_analysis)
      @ai_analysis = ai_analysis
    end

    def call
      return unless claim!

      perform_analysis
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
      Ai::Providers::Openai
    end

    def validate_result!(result)
      unless AiAnalysis::SENTIMENTS.include?(result.sentiment.to_s)
        raise "Invalid sentiment returned: #{result.sentiment}"
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
  end
end
