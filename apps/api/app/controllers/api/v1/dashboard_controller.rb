# frozen_string_literal: true

module Api
  module V1
    class DashboardController < BaseController
      include Authenticatable
      include Authorizable
      before_action :authenticate_user!

      def show
        authorize! :read
        render json: { data: dashboard_data }
      end

      private

      def dashboard_data
        {
          total_tickets: total_tickets,
          analyzed_tickets: analyzed_tickets_count,
          sentiment_distribution: sentiment_distribution,
          top_categories: top_categories,
          feature_requests: feature_request_count,
          bug_reports: bug_report_count
        }
      end

      def analyses
        @analyses ||= current_organization.ai_analyses.where(status: "completed")
      end

      def total_tickets
        current_organization.tickets.count
      end

      def analyzed_tickets_count
        analyses.count
      end

      def sentiment_distribution
        analyses.group(:sentiment).count
      end

      def top_categories
        analyses
          .where.not(category: [ nil, "" ])
          .group(:category)
          .order(Arel.sql("count(*) DESC"))
          .limit(10)
          .count
      end

      def feature_request_count
        analyses.where(feature_request: true).count
      end

      def bug_report_count
        analyses.where(bug_report: true).count
      end
    end
  end
end
