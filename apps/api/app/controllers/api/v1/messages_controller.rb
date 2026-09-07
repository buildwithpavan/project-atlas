# frozen_string_literal: true

module Api
  module V1
    class MessagesController < BaseController
      include Authenticatable
      include Authorizable
      before_action :authenticate_user!

      rescue_from OpenAI::Errors::APIError, AiProcessingError, with: :render_ai_error
      rescue_from AiQuotaExceededError, with: :render_quota_exceeded

      def create
        authorize! :read
        conversation = find_conversation!

        # ── Quota enforcement ──────────────────────────────────────────
        ::Ai::QuotaEnforcer.call(organization: current_organization)

        # ── Idempotency check ──────────────────────────────────────────
        if idempotency_key_header.present?
          existing = find_idempotency_record(conversation)
          if existing
            return replay_idempotent_response(existing)
          end
        end

        # ── Reserve quota (concurrency-safe) ───────────────────────────
        ::Ai::QuotaEnforcer.reserve!(organization: current_organization)

        # ── Reservation-protected section ──────────────────────────────
        # ensure block guarantees release even on unexpected errors
        # (e.g. user message validation failure, unknown exceptions)
        begin
          # ── User message ───────────────────────────────────────────────
          user_message = create_message_with_position!(conversation,
            organization: current_organization,
            role: "user",
            content: message_params[:content]
          )

          # ── RAG pipeline ───────────────────────────────────────────────
          rag_result = ::Ai::AskAtlas.call(
            conversation: conversation,
            user_message: user_message,
            request_id: request.request_id
          )
        ensure
          # ── Release reservation (tokens now tracked in AiUsageRecord) ──
          begin
            ::Ai::QuotaEnforcer.release_reservation!(organization: current_organization)
          rescue StandardError => release_error
            Rails.logger.error(
              "[AiQuota] Failed to release reservation: #{release_error.class}: #{release_error.message}"
            )
          end
        end

        # ── Assistant message ──────────────────────────────────────────
        assistant_message = create_message_with_position!(conversation,
          organization: current_organization,
          role: "assistant",
          content: rag_result.content,
          ai_model: rag_result.model,
          input_tokens: rag_result.prompt_tokens,
          output_tokens: rag_result.completion_tokens,
          embedding_tokens: rag_result.embedding_tokens,
          retrieval_count: rag_result.retrieval_count,
          retrieval_max_similarity: rag_result.retrieval_max_similarity,
          latency_ms: rag_result.latency_ms,
          citations: rag_result.citations
        )

        response_body = { data: serialize_assistant_message(assistant_message, rag_result) }

        # ── Persist idempotency record ─────────────────────────────────
        persist_idempotency_record(conversation, user_message, assistant_message, response_body)

        # ── Record AI usage (best-effort) ──────────────────────────────
        record_ai_usage(conversation, assistant_message, rag_result)

        render json: response_body, status: :created
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
        raise unless e.record&.role == "assistant"

        render_ai_error(e)
      end

      private

      def find_conversation!
        current_organization
          .conversations
          .where(user: current_user)
          .find_by!(id: params[:conversation_id])
      rescue ActiveRecord::RecordNotFound
        raise NotFoundError, "Conversation not found"
      end

      def next_position(conversation)
        conversation.with_lock do
          (conversation.messages.maximum(:position) || -1) + 1
        end
      rescue ActiveRecord::RecordNotUnique
        retry
      end

      def create_message_with_position!(conversation, attrs)
        position = next_position(conversation)
        conversation.messages.create!(attrs.merge(position: position))
      rescue ActiveRecord::RecordNotUnique => e
        raise unless e.message.include?("index_messages_on_conversation_id_and_position")

        retry
      end

      def message_params
        params.require(:message).permit(:content)
      end

      # ── Idempotency ────────────────────────────────────────────────────

      def idempotency_key_header
        request.headers["Idempotency-Key"]
      end

      def request_fingerprint
        Digest::SHA256.hexdigest("#{params[:conversation_id]}:#{message_params[:content]}")
      end

      def find_idempotency_record(conversation)
        IdempotencyKey.find_by(
          organization: current_organization,
          user: current_user,
          key: idempotency_key_header,
          conversation: conversation
        )
      end

      def replay_idempotent_response(record)
        if record.request_fingerprint != request_fingerprint
          render json: {
            type: "/errors/idempotency-mismatch",
            title: "Idempotency Key Conflict",
            status: 422,
            detail: "This idempotency key has already been used with different request parameters."
          }, status: :unprocessable_entity
          return
        end

        render json: record.response_body, status: record.response_status
      end

      def persist_idempotency_record(conversation, user_message, assistant_message, response_body)
        return unless idempotency_key_header.present?

        IdempotencyKey.create!(
          organization: current_organization,
          user: current_user,
          key: idempotency_key_header,
          conversation: conversation,
          request_fingerprint: request_fingerprint,
          user_message: user_message,
          assistant_message: assistant_message,
          response_body: response_body,
          response_status: 201
        )
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
        # Concurrent request with the same key already inserted — safe to ignore.
        raise unless e.is_a?(ActiveRecord::RecordNotUnique) || e.record.is_a?(IdempotencyKey)
      end

      # ── Usage Recording ─────────────────────────────────────────────────

      def record_ai_usage(conversation, assistant_message, rag_result)
        prompt_tokens = rag_result.prompt_tokens || 0
        completion_tokens = rag_result.completion_tokens || 0
        embedding_tokens = rag_result.embedding_tokens || 0

        # Chat usage
        chat_cost = ::Ai::ModelPricing.estimate(
          model: rag_result.model || "unknown",
          prompt_tokens: prompt_tokens,
          completion_tokens: completion_tokens
        )
        AiUsageRecord.create!(
          organization: current_organization,
          user: current_user,
          conversation: conversation,
          message: assistant_message,
          provider: "openai",
          model: rag_result.model || "unknown",
          operation: "chat",
          prompt_tokens: prompt_tokens,
          completion_tokens: completion_tokens,
          total_tokens: prompt_tokens + completion_tokens,
          estimated_cost: chat_cost,
          request_id: request.request_id,
          latency_ms: rag_result.generation_latency_ms
        )

        # Embedding usage
        embed_cost = ::Ai::ModelPricing.estimate(
          model: ::Ai::AskAtlas::EMBEDDING_MODEL,
          prompt_tokens: embedding_tokens
        )
        AiUsageRecord.create!(
          organization: current_organization,
          user: current_user,
          conversation: conversation,
          message: assistant_message,
          provider: "openai",
          model: ::Ai::AskAtlas::EMBEDDING_MODEL,
          operation: "embedding",
          prompt_tokens: embedding_tokens,
          completion_tokens: 0,
          total_tokens: embedding_tokens,
          estimated_cost: embed_cost,
          request_id: request.request_id,
          latency_ms: rag_result.embedding_latency_ms
        )
      rescue StandardError => e
        # Usage recording is best-effort — do not fail the user's chat request
        Rails.logger.error("[AiUsage] Failed to record usage: #{e.class}: #{e.message}")
      end

      # ── Serialization ──────────────────────────────────────────────────

      def serialize_assistant_message(message, rag_result)
        {
          id: message.id,
          role: message.role,
          content: message.content,
          position: message.position,
          citations: message.citations,
          has_sources: rag_result.has_sources,
          model: message.ai_model,
          prompt_tokens: message.input_tokens,
          completion_tokens: message.output_tokens,
          embedding_tokens: message.embedding_tokens,
          retrieval_count: message.retrieval_count,
          retrieval_max_similarity: message.retrieval_max_similarity,
          latency_ms: message.latency_ms,
          created_at: message.created_at.iso8601
        }
      end

      def render_ai_error(_error)
        render json: {
          type: "/errors/ai-processing",
          title: "AI Processing Error",
          status: 500,
          detail: "An error occurred while processing your request with the AI service."
        }, status: :internal_server_error
      end

      def render_quota_exceeded(error)
        render json: {
          type: "/errors/ai-quota-exceeded",
          title: "AI Quota Exceeded",
          status: 429,
          detail: "Your organization has exceeded its AI usage limit. Please try again later or contact your administrator."
        }, status: :too_many_requests
      end
    end
  end
end
