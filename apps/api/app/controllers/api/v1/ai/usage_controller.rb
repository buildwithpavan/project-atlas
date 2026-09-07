# frozen_string_literal: true

module Api
  module V1
    module Ai
      # AI usage reporting endpoint.
      #
      # GET /api/v1/ai/usage → usage with breakdowns
      #
      # Supports:
      #   ?period=2026-08        → specific month (default: current month)
      #   ?period=previous       → previous calendar month
      #   ?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD → custom date range
      #
      # All queries use SQL aggregation — no large datasets loaded into Ruby.
      # Organization is derived from authenticated user's membership.
      class UsageController < BaseController
      include Authenticatable
      include Authorizable
      before_action :authenticate_user!

      # GET /api/v1/ai/usage
      def show
        authorize! :read

        Rails.logger.info("[AiUsage] usage_queried organization_id=#{current_organization.id} user_id=#{current_user.id}")

        render json: { data: build_usage_report }
      end

      private

      def build_usage_report
        scope = period_scope
        period_label = resolve_period_label

        totals = scope.pick(
          Arel.sql("COALESCE(SUM(total_tokens), 0)"),
          Arel.sql("COALESCE(SUM(prompt_tokens), 0)"),
          Arel.sql("COALESCE(SUM(completion_tokens), 0)"),
          Arel.sql("COALESCE(SUM(estimated_cost), 0)"),
          Arel.sql("COUNT(*)"),
          Arel.sql("COALESCE(AVG(latency_ms), 0)")
        )
        tokens_used = totals[0].to_i
        cost_used = totals[3].to_f

        token_limit = current_organization.ai_monthly_token_limit
        cost_limit = current_organization.ai_monthly_cost_limit

        {
          period: period_label,
          tokens: build_limit_section(tokens_used, token_limit),
          cost: build_limit_section(cost_used.round(6), cost_limit&.to_f),
          prompt_tokens: totals[1].to_i,
          completion_tokens: totals[2].to_i,
          request_count: totals[4].to_i,
          average_latency_ms: totals[5].to_f.round(1),
          by_operation: by_operation(scope),
          by_model: by_model(scope),
          by_user: by_user(scope),
          by_day: by_day(scope)
        }
      end

      def build_limit_section(used, limit)
        section = { used: used }

        if limit
          remaining = [(limit.is_a?(Float) ? (limit - used).round(6) : limit - used), 0].max
          percentage = limit > 0 ? (used.to_f / limit * 100).round(2) : 100.0

          section.merge(
            limit: limit,
            remaining: remaining,
            percentage_used: percentage
          )
        else
          section.merge(
            limit: nil,
            remaining: nil,
            percentage_used: nil
          )
        end
      end

      def by_operation(scope)
        scope.group(:operation).pluck(
          Arel.sql("operation"),
          Arel.sql("COALESCE(SUM(total_tokens), 0)"),
          Arel.sql("COALESCE(SUM(prompt_tokens), 0)"),
          Arel.sql("COALESCE(SUM(completion_tokens), 0)"),
          Arel.sql("COALESCE(SUM(estimated_cost), 0)"),
          Arel.sql("COUNT(*)"),
          Arel.sql("COALESCE(AVG(latency_ms), 0)")
        ).map do |operation, tokens, prompt, completion, cost, count, latency|
          {
            operation: operation,
            total_tokens: tokens.to_i,
            prompt_tokens: prompt.to_i,
            completion_tokens: completion.to_i,
            estimated_cost: cost.to_f.round(6),
            request_count: count.to_i,
            average_latency_ms: latency.to_f.round(1)
          }
        end
      end

      def by_model(scope)
        scope.group(:model).pluck(
          Arel.sql("model"),
          Arel.sql("COALESCE(SUM(total_tokens), 0)"),
          Arel.sql("COALESCE(SUM(estimated_cost), 0)"),
          Arel.sql("COUNT(*)")
        ).map do |model, tokens, cost, count|
          {
            model: model,
            total_tokens: tokens.to_i,
            estimated_cost: cost.to_f.round(6),
            request_count: count.to_i
          }
        end
      end

      def by_user(scope)
        scope.joins("INNER JOIN users ON users.id = ai_usage_records.user_id")
             .group("ai_usage_records.user_id", "users.email")
             .pluck(
               Arel.sql("ai_usage_records.user_id"),
               Arel.sql("users.email"),
               Arel.sql("COALESCE(SUM(ai_usage_records.total_tokens), 0)"),
               Arel.sql("COALESCE(SUM(ai_usage_records.estimated_cost), 0)"),
               Arel.sql("COUNT(*)")
             ).map do |user_id, email, tokens, cost, count|
          {
            user_id: user_id,
            email: email,
            total_tokens: tokens.to_i,
            estimated_cost: cost.to_f.round(6),
            request_count: count.to_i
          }
        end
      end

      def by_day(scope)
        scope.group(Arel.sql("DATE(created_at)"))
             .order(Arel.sql("DATE(created_at)"))
             .pluck(
               Arel.sql("DATE(created_at)"),
               Arel.sql("COALESCE(SUM(total_tokens), 0)"),
               Arel.sql("COALESCE(SUM(estimated_cost), 0)"),
               Arel.sql("COUNT(*)")
             ).map do |date, tokens, cost, count|
          {
            date: date.to_s,
            total_tokens: tokens.to_i,
            estimated_cost: cost.to_f.round(6),
            request_count: count.to_i
          }
        end
      end

      # Determine the time scope based on query params.
      # Supports: ?period=2026-08, ?period=previous, ?start_date=...&end_date=...
      def period_scope
        base = AiUsageRecord.where(organization_id: current_organization.id)

        if params[:start_date].present? && params[:end_date].present?
          start_date = Date.parse(params[:start_date]).beginning_of_day
          end_date = Date.parse(params[:end_date]).end_of_day
          base.where(created_at: start_date..end_date)
        elsif params[:period] == "previous"
          month_start = 1.month.ago.beginning_of_month
          month_end = 1.month.ago.end_of_month
          base.where(created_at: month_start..month_end)
        elsif params[:period].present? && params[:period].match?(/\A\d{4}-\d{2}\z/)
          month_start = Date.parse("#{params[:period]}-01").beginning_of_day
          month_end = month_start.end_of_month.end_of_day
          base.where(created_at: month_start..month_end)
        else
          base.where(created_at: Time.current.beginning_of_month..)
        end
      rescue Date::Error
        # Invalid date format — fall back to current month
        base.where(created_at: Time.current.beginning_of_month..)
      end

      def resolve_period_label
        if params[:start_date].present? && params[:end_date].present?
          "#{params[:start_date]}..#{params[:end_date]}"
        elsif params[:period] == "previous"
          1.month.ago.strftime("%Y-%m")
        elsif params[:period].present? && params[:period].match?(/\A\d{4}-\d{2}\z/)
          params[:period]
        else
          Time.current.strftime("%Y-%m")
        end
      end
    end
  end
end
end
