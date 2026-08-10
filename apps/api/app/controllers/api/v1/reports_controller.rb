# frozen_string_literal: true

module Api
  module V1
    class ReportsController < BaseController
      include Authenticatable
      before_action :authenticate_user!

      def index
        render json: { data: report_data }
      end

      private

      def organization
        @organization ||= begin
          org = current_user.organizations.first
          raise UnauthorizedError, "No organization access" unless org
          org
        end
      end

      def tickets
        @tickets ||= organization.tickets
      end

      def analyses
        @analyses ||= organization.ai_analyses.where(status: "completed")
      end

      def report_data
        {
          metadata: metadata,
          tickets: ticket_metrics,
          sentiment: sentiment_metrics,
          categories: category_metrics,
          classifications: classification_metrics,
          status_distribution: status_distribution,
          priority_distribution: priority_distribution,
          timeline: timeline_metrics
        }
      end

      def metadata
        {
          generated_at: Time.current.iso8601,
          organization_name: organization.name
        }
      end

      def ticket_metrics
        total = tickets.count
        analyzed = analyses.count
        {
          total: total,
          analyzed: analyzed,
          unanalyzed: total - analyzed
        }
      end

      def sentiment_metrics
        distribution = analyses.group(:sentiment).count
        total = analyses.count
        percentages = if total > 0
          distribution.transform_values { |v| (v * 100.0 / total).round(1) }
        else
          {}
        end

        {
          distribution: distribution,
          percentages: percentages
        }
      end

      def category_metrics
        distribution = analyses
          .where.not(category: [ nil, "" ])
          .group(:category)
          .order(Arel.sql("count(*) DESC"))
          .count

        {
          distribution: distribution,
          top: distribution.first(10).to_h
        }
      end

      def classification_metrics
        {
          feature_requests: analyses.where(feature_request: true).count,
          bug_reports: analyses.where(bug_report: true).count,
          knowledge_gaps: analyses.where(knowledge_gap: true).count
        }
      end

      def status_distribution
        tickets.group(:status).count
      end

      def priority_distribution
        tickets.group(:priority).count
      end

      def timeline_metrics
        tickets
          .group(Arel.sql("date_trunc('month', created_at)"))
          .order(Arel.sql("date_trunc('month', created_at)"))
          .count
          .transform_keys { |k| k.strftime("%Y-%m") }
      end
    end
  end
end
