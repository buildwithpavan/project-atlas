# frozen_string_literal: true

module Api
  module V1
    class TicketsController < BaseController
      include Authenticatable
      include Authorizable
      before_action :authenticate_user!

      def index
        authorize! :read
        tickets = scoped_tickets
        tickets = apply_search(tickets)
        tickets = apply_filters(tickets)
        tickets = tickets.order(created_at: :desc)
        tickets = paginate(tickets)

        render json: {
          data: tickets.map { |t| serialize_ticket(t) },
          meta: pagination_meta(tickets)
        }
      end

      def show
        authorize! :read
        ticket = scoped_tickets.includes(:ai_analysis).find_by(id: params[:id])
        raise NotFoundError, "Ticket not found" unless ticket

        render json: { data: serialize_ticket_detail(ticket) }
      end

      private

      def scoped_tickets
        current_organization.tickets
      end

      def apply_search(tickets)
        return tickets unless params[:search].present?

        search_term = "%#{sanitize_sql_like(params[:search])}%"
        tickets.where("subject ILIKE :term OR description ILIKE :term OR customer_name ILIKE :term", term: search_term)
      end

      def apply_filters(tickets)
        tickets = tickets.where(status: params[:status]) if params[:status].present?
        tickets = tickets.where(priority: params[:priority]) if params[:priority].present?
        tickets = tickets.where(category: params[:category]) if params[:category].present?
        tickets
      end

      def paginate(tickets)
        page = [ (params[:page] || 1).to_i, 1 ].max
        per_page = [ [ (params[:per_page] || 25).to_i, 1 ].max, 100 ].min

        tickets.offset((page - 1) * per_page).limit(per_page)
      end

      def pagination_meta(tickets)
        page = [ (params[:page] || 1).to_i, 1 ].max
        per_page = [ [ (params[:per_page] || 25).to_i, 1 ].max, 100 ].min
        total = scoped_tickets_count

        {
          page: page,
          per_page: per_page,
          total: total,
          total_pages: (total.to_f / per_page).ceil
        }
      end

      def scoped_tickets_count
        tickets = scoped_tickets
        tickets = apply_search(tickets)
        tickets = apply_filters(tickets)
        tickets.count
      end

      def serialize_ticket(ticket)
        {
          id: ticket.id,
          subject: ticket.subject,
          status: ticket.status,
          priority: ticket.priority,
          category: ticket.category,
          customer_name: ticket.customer_name,
          customer_email: ticket.customer_email,
          created_at: ticket.created_at.iso8601,
          updated_at: ticket.updated_at.iso8601
        }
      end

      def serialize_ticket_detail(ticket)
        serialize_ticket(ticket).merge(
          description: ticket.description,
          upload_id: ticket.upload_id,
          ai_analysis: ticket.ai_analysis ? serialize_ai_analysis(ticket.ai_analysis) : nil
        )
      end

      def serialize_ai_analysis(analysis)
        {
          id: analysis.id,
          status: analysis.status,
          sentiment: analysis.sentiment,
          summary: analysis.summary,
          category: analysis.category,
          confidence: analysis.confidence&.to_f,
          feature_request: analysis.feature_request,
          bug_report: analysis.bug_report,
          knowledge_gap: analysis.knowledge_gap,
          processed_at: analysis.processed_at&.iso8601
        }
      end

      def sanitize_sql_like(string)
        ActiveRecord::Base.sanitize_sql_like(string)
      end
    end
  end
end
