# frozen_string_literal: true

module Api
  module V1
    class ConversationsController < BaseController
      include Authenticatable
      include Authorizable
      before_action :authenticate_user!

      def index
        authorize! :read
        conversations = scoped_conversations.order(created_at: :desc)
        conversations = paginate(conversations)

        render json: {
          data: conversations.map { |c| serialize_conversation(c) },
          meta: pagination_meta
        }
      end

      def show
        authorize! :read
        conversation = find_conversation!

        render json: {
          data: serialize_conversation_detail(conversation)
        }
      end

      def create
        authorize! :read
        conversation = current_organization.conversations.create!(
          user: current_user,
          title: params.dig(:conversation, :title)
        )

        render json: { data: serialize_conversation(conversation) }, status: :created
      end

      def destroy
        authorize! :write
        conversation = find_conversation!
        conversation.destroy!

        head :no_content
      end

      private

      def scoped_conversations
        current_organization.conversations.where(user: current_user)
      end

      def paginate(conversations)
        page = [ (params[:page] || 1).to_i, 1 ].max
        per_page = [ [ (params[:per_page] || 25).to_i, 1 ].max, 100 ].min

        conversations.offset((page - 1) * per_page).limit(per_page)
      end

      def pagination_meta
        page = [ (params[:page] || 1).to_i, 1 ].max
        per_page = [ [ (params[:per_page] || 25).to_i, 1 ].max, 100 ].min
        total = scoped_conversations.count

        {
          page: page,
          per_page: per_page,
          total: total,
          total_pages: (total.to_f / per_page).ceil
        }
      end

      def find_conversation!
        scoped_conversations.find_by!(id: params[:id])
      rescue ActiveRecord::RecordNotFound
        raise NotFoundError, "Conversation not found"
      end

      def serialize_conversation(conversation)
        {
          id: conversation.id,
          title: conversation.title,
          created_at: conversation.created_at.iso8601,
          updated_at: conversation.updated_at.iso8601
        }
      end

      def serialize_conversation_detail(conversation)
        serialize_conversation(conversation).merge(
          messages: conversation.messages.order(position: :asc).map { |m| serialize_message(m) }
        )
      end

      def serialize_message(message)
        base = {
          id: message.id,
          role: message.role,
          content: message.content,
          position: message.position,
          created_at: message.created_at.iso8601
        }

        if message.role == "assistant"
          base.merge(
            citations: message.citations || [],
            has_sources: message.citations.present?,
            model: message.ai_model,
            prompt_tokens: message.input_tokens,
            completion_tokens: message.output_tokens,
            embedding_tokens: message.embedding_tokens,
            retrieval_count: message.retrieval_count,
            retrieval_max_similarity: message.retrieval_max_similarity,
            latency_ms: message.latency_ms
          )
        else
          base
        end
      end
    end
  end
end
