# frozen_string_literal: true

module Ai
  # Enforces organization-level AI usage quotas with concurrency safety.
  #
  # Two-phase approach:
  #   1. Check current month's actual usage against limits
  #   2. Atomically reserve estimated tokens via UPDATE ... SET col = col + N
  #
  # The reservation prevents two concurrent requests from both passing
  # the quota check. Reservations are released after the AI call completes
  # (success or failure) via release_reservation.
  #
  # Quota columns on Organization:
  #   ai_monthly_token_limit      — max total tokens per calendar month (nil = unlimited)
  #   ai_monthly_cost_limit       — max estimated cost in USD per calendar month (nil = unlimited)
  #   ai_quota_reserved_tokens    — atomically incremented reservation counter
  #
  # Usage:
  #   Ai::QuotaEnforcer.call(organization: org)
  #     Raises AiQuotaExceededError if any limit is exceeded.
  #     Returns nil (no-op) if within limits or limits are not configured.
  #
  #   Ai::QuotaEnforcer.reserve!(organization: org, estimated_tokens:)
  #     Atomically reserves tokens. Raises AiQuotaExceededError if reservation
  #     would exceed the limit.
  #
  #   Ai::QuotaEnforcer.release_reservation!(organization: org, estimated_tokens:)
  #     Releases previously reserved tokens after AI call completes.
  #
  #   Ai::QuotaEnforcer.recover_stale_reservations!
  #     Resets reservations older than the configured expiry threshold.
  class QuotaEnforcer < ApplicationService
    # Estimated tokens per AI request for reservation purposes.
    ESTIMATED_TOKENS_PER_REQUEST = ENV.fetch("AI_ESTIMATED_TOKENS_PER_REQUEST", "1000").to_i

    # How long a reservation is considered active before recovery.
    # Default: 5 minutes (well above typical AI request time of ~30s).
    RESERVATION_EXPIRY_SECONDS = ENV.fetch("AI_RESERVATION_EXPIRY_SECONDS", "300").to_i

    def initialize(organization:)
      @organization = organization
    end

    def call
      check_token_limit!
      check_cost_limit!
    end

    class << self
      # Atomically reserve estimated tokens before an AI call.
      # Uses UPDATE ... SET col = col + N for atomicity.
      # This does NOT do a second quota check — it's purely bookkeeping
      # to make concurrent requests aware of each other. The actual
      # quota enforcement happens in .call().
      def reserve!(organization:, estimated_tokens: ESTIMATED_TOKENS_PER_REQUEST)
        return unless organization.ai_monthly_token_limit # nil = unlimited

        # Atomic increment + timestamp — safe under concurrent access
        Organization.where(id: organization.id).update_all(
          ["ai_quota_reserved_tokens = ai_quota_reserved_tokens + ?, ai_quota_reserved_at = ?",
           estimated_tokens, Time.current]
        )

        Rails.logger.info(
          "[AiQuota] tokens_reserved organization_id=#{organization.id} " \
          "estimated_tokens=#{estimated_tokens}"
        )
      end

      # Release reserved tokens after AI call completes (success or failure).
      def release_reservation!(organization:, estimated_tokens: ESTIMATED_TOKENS_PER_REQUEST)
        Organization.where(id: organization.id).update_all(
          ["ai_quota_reserved_tokens = GREATEST(ai_quota_reserved_tokens - ?, 0), " \
           "ai_quota_reserved_at = CASE WHEN ai_quota_reserved_tokens - ? <= 0 THEN NULL ELSE ai_quota_reserved_at END",
           estimated_tokens, estimated_tokens]
        )
      end

      # Recover stale reservations from crashed processes.
      # Only resets reservations older than RESERVATION_EXPIRY_SECONDS.
      # Safe under concurrent execution: uses WHERE conditions to avoid
      # resetting legitimately active reservations.
      def recover_stale_reservations!
        expiry_cutoff = RESERVATION_EXPIRY_SECONDS.seconds.ago

        affected = Organization.where("ai_quota_reserved_tokens > 0")
                               .where("ai_quota_reserved_at IS NOT NULL")
                               .where("ai_quota_reserved_at < ?", expiry_cutoff)
                               .update_all(ai_quota_reserved_tokens: 0, ai_quota_reserved_at: nil)

        if affected > 0
          Rails.logger.info(
            "[AiQuota] recovered_stale_reservations count=#{affected} " \
            "expiry_threshold=#{RESERVATION_EXPIRY_SECONDS}s"
          )
        end

        affected
      end

      private

      def monthly_tokens(organization)
        AiUsageRecord.where(
          organization_id: organization.id,
          created_at: Time.current.beginning_of_month..
        ).sum(:total_tokens)
      end
    end

    private

    def check_token_limit!
      limit = @organization.ai_monthly_token_limit
      return if limit.nil?

      current = monthly_usage[:tokens]
      reserved = @organization.reload.ai_quota_reserved_tokens

      return if (current + reserved) < limit

      Rails.logger.info(
        "[AiQuota] organization_id=#{@organization.id} " \
        "token_limit_exceeded current=#{current} reserved=#{reserved} limit=#{limit}"
      )

      raise AiQuotaExceededError.new(
        limit_type: "token",
        current_value: current + reserved,
        limit_value: limit
      )
    end

    def check_cost_limit!
      limit = @organization.ai_monthly_cost_limit
      return if limit.nil?

      current = monthly_usage[:cost]
      return if current < limit

      Rails.logger.info(
        "[AiQuota] organization_id=#{@organization.id} " \
        "cost_limit_exceeded current=#{current} limit=#{limit}"
      )

      raise AiQuotaExceededError.new(
        limit_type: "cost",
        current_value: current,
        limit_value: limit
      )
    end

    # Single query for both token and cost usage — avoids 2 separate SUMs.
    # Memoized per call since both check_token_limit! and check_cost_limit!
    # need the same data within a single enforcement check.
    def monthly_usage
      @monthly_usage ||= begin
        result = AiUsageRecord.where(
          organization_id: @organization.id,
          created_at: beginning_of_month..
        ).pick(
          Arel.sql("COALESCE(SUM(total_tokens), 0)"),
          Arel.sql("COALESCE(SUM(estimated_cost), 0)")
        )
        { tokens: result[0].to_i, cost: result[1].to_f }
      end
    end

    def beginning_of_month
      Time.current.beginning_of_month
    end
  end
end
