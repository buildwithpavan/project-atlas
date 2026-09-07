# frozen_string_literal: true

module Api
  module V1
    module Ai
      # Organization AI quota management.
      #
      # GET  /api/v1/ai/quota   → view current quota configuration and usage
      # PATCH /api/v1/ai/quota  → update quota limits (admin+ only)
      #
      # Organization is derived from the authenticated user's membership.
      # Never trusts client-supplied organization_id.
      class QuotaController < BaseController
      include Authenticatable
      include Authorizable
      before_action :authenticate_user!

      # GET /api/v1/ai/quota
      # Any authenticated org member can view quota status.
      def show
        authorize! :read

        Rails.logger.info("[AiQuota] quota_viewed organization_id=#{current_organization.id} user_id=#{current_user.id}")

        render json: { data: serialize_quota }
      end

      # PATCH /api/v1/ai/quota
      # Only admin+ can modify quota limits.
      def update
        authorize! :manage

        validate_quota_params!

        current_organization.update!(quota_params)

        Rails.logger.info(
          "[AiQuota] quota_updated organization_id=#{current_organization.id} " \
          "user_id=#{current_user.id} " \
          "token_limit=#{current_organization.ai_monthly_token_limit.inspect} " \
          "cost_limit=#{current_organization.ai_monthly_cost_limit.inspect}"
        )

        render json: { data: serialize_quota }
      end

      private

      def quota_params
        params.require(:quota).permit(:ai_monthly_token_limit, :ai_monthly_cost_limit)
      end

      def validate_quota_params!
        qp = quota_params

        validate_limit_value!(qp, :ai_monthly_token_limit, integer: true)
        validate_limit_value!(qp, :ai_monthly_cost_limit, integer: false)
      end

      def validate_limit_value!(qp, field, integer:)
        return unless qp.key?(field.to_s)

        value = qp[field.to_s]

        # nil means unlimited — explicitly allowed
        return if value.nil?

        # Coerce to numeric for validation
        if integer
          unless value.to_s.match?(/\A\d+\z/)
            raise ValidationError.new("#{field} must be a non-negative integer or null", errors: { field => ["must be a non-negative integer or null"] })
          end
          numeric = value.to_i
        else
          begin
            numeric = BigDecimal(value.to_s)
          rescue ArgumentError
            raise ValidationError.new("#{field} must be a non-negative number or null", errors: { field => ["must be a non-negative number or null"] })
          end
          unless numeric >= 0
            raise ValidationError.new("#{field} must be a non-negative number or null", errors: { field => ["must be a non-negative number or null"] })
          end
        end

        if numeric.negative?
          raise ValidationError.new("#{field} must be non-negative", errors: { field => ["must be non-negative"] })
        end
      end

      def serialize_quota
        usage = current_month_usage

        token_limit = current_organization.ai_monthly_token_limit
        cost_limit = current_organization.ai_monthly_cost_limit

        {
          ai_monthly_token_limit: token_limit,
          ai_monthly_cost_limit: cost_limit&.to_f,
          ai_quota_reserved_tokens: current_organization.ai_quota_reserved_tokens,
          period: Time.current.strftime("%Y-%m"),
          current_month: {
            tokens_used: usage[:tokens],
            cost_used: usage[:cost].to_f.round(6),
            tokens_remaining: token_limit ? [token_limit - usage[:tokens], 0].max : nil,
            cost_remaining: cost_limit ? [(cost_limit - usage[:cost]).to_f.round(2), 0].max : nil,
            token_percentage_used: token_limit && token_limit > 0 ? (usage[:tokens].to_f / token_limit * 100).round(2) : nil,
            cost_percentage_used: cost_limit && cost_limit > 0 ? (usage[:cost].to_f / cost_limit.to_f * 100).round(2) : nil
          }
        }
      end

      def current_month_usage
        result = AiUsageRecord.where(
          organization_id: current_organization.id,
          created_at: Time.current.beginning_of_month..
        ).pick(
          Arel.sql("COALESCE(SUM(total_tokens), 0)"),
          Arel.sql("COALESCE(SUM(estimated_cost), 0)")
        )

        {
          tokens: result[0].to_i,
          cost: result[1]
        }
      end
    end
  end
end
end
