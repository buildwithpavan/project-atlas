# frozen_string_literal: true

module Api
  module V1
    class ThemesController < BaseController
      include Authenticatable
      include Authorizable
      before_action :authenticate_user!

      def index
        authorize! :read

        themes = scoped_themes
        themes = apply_filters(themes)
        themes = themes.order(ticket_count: :desc, last_seen_at: :desc)

        render json: {
          data: themes.map { |t| serialize_theme(t) },
          meta: { total: themes.size }
        }
      end

      def show
        authorize! :read

        theme = scoped_themes
          .includes(theme_memberships: :ticket)
          .find_by(id: params[:id])
        raise NotFoundError, "Theme not found" unless theme

        render json: { data: serialize_theme_detail(theme) }
      end

      def detect
        authorize! :manage

        DetectThemesJob.perform_later(current_organization.id)

        render json: {
          data: { message: "Theme detection started" }
        }, status: :accepted
      end

      private

      def scoped_themes
        current_organization.themes
      end

      def apply_filters(themes)
        themes = themes.where(status: params[:status]) if params[:status].present?
        themes = themes.where(severity: params[:severity]) if params[:severity].present?
        themes
      end

      def serialize_theme(theme)
        {
          id: theme.id,
          title: theme.title,
          description: theme.description,
          status: theme.status,
          severity: theme.severity,
          ticket_count: theme.ticket_count,
          evidence_summary: theme.evidence_summary,
          recommended_action: theme.recommended_action,
          first_seen_at: theme.first_seen_at&.iso8601,
          last_seen_at: theme.last_seen_at&.iso8601,
          created_at: theme.created_at.iso8601
        }
      end

      def serialize_theme_detail(theme)
        serialize_theme(theme).merge(
          tickets: theme.theme_memberships.map do |membership|
            ticket = membership.ticket
            {
              id: ticket.id,
              subject: ticket.subject,
              customer_name: ticket.customer_name,
              priority: ticket.priority,
              status: ticket.status,
              relevance_score: membership.relevance_score&.to_f,
              evidence_text: membership.evidence_text,
              created_at: ticket.created_at.iso8601
            }
          end
        )
      end
    end
  end
end
