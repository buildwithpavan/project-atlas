# frozen_string_literal: true

module Api
  module V1
    class ExecutiveSummariesController < BaseController
      include Authenticatable
      include Authorizable
      before_action :authenticate_user!

      def show
        authorize! :read
        summary = current_organization.executive_summary
        raise NotFoundError, "No executive summary has been generated yet" unless summary

        render json: { data: serialize(summary) }
      end

      def create
        authorize! :manage
        summary = ::Ai::GenerateExecutiveSummary.call(current_organization)

        render json: { data: serialize(summary) }, status: :created
      rescue ValidationError, UnauthorizedError, ForbiddenError, NotFoundError => e
        raise e
      rescue KeyError => e
        raise ApplicationError.new(
          title: "Configuration Error",
          detail: "AI provider is not configured",
          status: :service_unavailable,
          type: "/errors/ai-unavailable"
        )
      rescue StandardError => e
        raise ApplicationError.new(
          title: "Generation Failed",
          detail: "Unable to generate executive summary. Please try again.",
          status: :unprocessable_content,
          type: "/errors/generation-failed"
        )
      end

      private

      def serialize(summary)
        {
          id: summary.id,
          summary: summary.summary,
          key_findings: summary.key_findings,
          attention_items: summary.attention_items,
          recommended_actions: summary.recommended_actions,
          analyzed_ticket_count: summary.analyzed_ticket_count,
          generated_at: summary.generated_at.iso8601,
          stale: stale?(summary)
        }
      end

      def stale?(summary)
        current_count = current_organization.ai_analyses.where(status: "completed").count
        current_count > summary.analyzed_ticket_count
      end
    end
  end
end
