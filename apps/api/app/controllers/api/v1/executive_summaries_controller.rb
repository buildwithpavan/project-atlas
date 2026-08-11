# frozen_string_literal: true

module Api
  module V1
    class ExecutiveSummariesController < BaseController
      include Authenticatable
      before_action :authenticate_user!

      def show
        summary = organization.executive_summary
        raise NotFoundError, "No executive summary has been generated yet" unless summary

        render json: { data: serialize(summary) }
      end

      def create
        summary = Ai::GenerateExecutiveSummary.call(organization)

        render json: { data: serialize(summary) }, status: :created
      rescue ValidationError, UnauthorizedError, NotFoundError => e
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

      def organization
        @organization ||= begin
          org = current_user.organizations.first
          raise UnauthorizedError, "No organization access" unless org
          org
        end
      end

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
        current_count = organization.ai_analyses.where(status: "completed").count
        current_count > summary.analyzed_ticket_count
      end
    end
  end
end
