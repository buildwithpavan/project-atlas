# frozen_string_literal: true

module Api
  module V1
    class DocumentsController < BaseController
      include Authenticatable
      include Authorizable
      before_action :authenticate_user!

      ALLOWED_CONTENT_TYPES = %w[
        application/pdf
        text/plain
        text/markdown
        text/csv
        text/x-markdown
      ].freeze

      MAX_FILE_SIZE = 50.megabytes

      def index
        authorize! :read
        documents = current_organization.documents.includes(:uploaded_by).order(created_at: :desc)
        documents = paginate(documents)

        render json: {
          data: documents.map { |d| serialize_document(d) },
          meta: pagination_meta
        }
      end

      def show
        authorize! :read
        document = find_document!

        render json: { data: serialize_document(document) }
      end

      def create
        authorize! :write
        validate_file!

        checksum = Digest::SHA256.hexdigest(file_param.read)
        file_param.rewind

        if current_organization.documents.exists?(checksum: checksum)
          raise ValidationError.new(
            "Duplicate document",
            errors: { checksum: [ "a document with this content already exists in this organization" ] }
          )
        end

        document = current_organization.documents.create!(
          title: params[:title].presence || file_param.original_filename,
          filename: file_param.original_filename,
          content_type: file_param.content_type,
          file_size: file_param.size,
          checksum: checksum,
          uploaded_by: current_user,
          status: "pending"
        )
        document.file.attach(file_param)

        ProcessDocumentJob.perform_later(document)

        render json: { data: serialize_document(document) }, status: :created
      end

      def destroy
        authorize! :manage
        document = find_document!
        document.destroy!

        head :no_content
      end

      def reprocess
        authorize! :manage
        document = find_document!

        if document.status == "processing"
          raise ValidationError.new(
            "Document is currently being processed",
            errors: { status: [ "cannot reprocess while document is processing" ] }
          )
        end

        document.update!(status: "pending", error_message: nil)

        ProcessDocumentJob.perform_later(document)

        render json: { data: serialize_document(document) }
      end

      private

      def find_document!
        current_organization.documents.find_by!(id: params[:id])
      rescue ActiveRecord::RecordNotFound
        raise NotFoundError, "Document not found"
      end

      def file_param
        @file_param ||= params.require(:file)
      end

      def validate_file!
        unless file_param.respond_to?(:original_filename)
          raise ValidationError.new("File is required", errors: { file: [ "must be a valid uploaded file" ] })
        end

        unless ALLOWED_CONTENT_TYPES.include?(file_param.content_type)
          raise ValidationError.new(
            "Unsupported file type",
            errors: { file: [ "must be PDF, TXT, Markdown, or CSV (got #{file_param.content_type})" ] }
          )
        end

        if file_param.size > MAX_FILE_SIZE
          raise ValidationError.new("File too large", errors: { file: [ "must be less than 50MB" ] })
        end
      end

      def paginate(documents)
        page = [ (params[:page] || 1).to_i, 1 ].max
        per_page = [ [ (params[:per_page] || 25).to_i, 1 ].max, 100 ].min

        documents.offset((page - 1) * per_page).limit(per_page)
      end

      def pagination_meta
        page = [ (params[:page] || 1).to_i, 1 ].max
        per_page = [ [ (params[:per_page] || 25).to_i, 1 ].max, 100 ].min
        total = current_organization.documents.count

        {
          page: page,
          per_page: per_page,
          total: total,
          total_pages: (total.to_f / per_page).ceil
        }
      end

      def serialize_document(document)
        {
          id: document.id,
          title: document.title,
          filename: document.filename,
          content_type: document.content_type,
          file_size: document.file_size,
          status: document.status,
          error_message: document.error_message,
          checksum: document.checksum,
          chunk_count: document.chunk_count,
          uploaded_by: serialize_uploaded_by(document),
          created_at: document.created_at.iso8601,
          updated_at: document.updated_at.iso8601
        }
      end

      def serialize_uploaded_by(document)
        return nil unless document.uploaded_by

        {
          id: document.uploaded_by.id,
          email: document.uploaded_by.email,
          first_name: document.uploaded_by.first_name,
          last_name: document.uploaded_by.last_name
        }
      end
    end
  end
end
