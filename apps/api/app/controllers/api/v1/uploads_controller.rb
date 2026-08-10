# frozen_string_literal: true

module Api
  module V1
    class UploadsController < BaseController
      include Authenticatable
      before_action :authenticate_user!

      MAX_FILE_SIZE = 25.megabytes

      def create
        organization = authorize_organization!
        validate_file!

        upload = organization.uploads.create!(
          filename: file_param.original_filename,
          uploaded_by: current_user
        )
        upload.file.attach(file_param)

        ProcessUploadJob.perform_later(upload)

        render json: { data: serialize_upload(upload) }, status: :created
      end

      private

      def authorize_organization!
        org = current_user.organizations.first
        raise UnauthorizedError, "No organization access" unless org

        org
      end

      def file_param
        @file_param ||= params.require(:file)
      end

      def validate_file!
        unless file_param.respond_to?(:original_filename)
          raise ValidationError.new("File is required", errors: { file: [ "must be a valid uploaded file" ] })
        end

        unless file_param.original_filename&.end_with?(".csv")
          raise ValidationError.new("Invalid file type", errors: { file: [ "must be a CSV file" ] })
        end

        if file_param.size > MAX_FILE_SIZE
          raise ValidationError.new("File too large", errors: { file: [ "must be less than 25MB" ] })
        end
      end

      def serialize_upload(upload)
        {
          id: upload.id,
          filename: upload.filename,
          status: upload.status,
          total_records: upload.total_records,
          processed_records: upload.processed_records,
          failed_records: upload.failed_records,
          created_at: upload.created_at.iso8601,
          updated_at: upload.updated_at.iso8601
        }
      end
    end
  end
end
