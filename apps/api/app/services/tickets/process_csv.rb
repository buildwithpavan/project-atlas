# frozen_string_literal: true

require "csv"

module Tickets
  class ProcessCsv < ApplicationService
    BATCH_SIZE = 1000
    REQUIRED_HEADERS = %w[subject].freeze
    ALLOWED_HEADERS = %w[subject description customer_name customer_email priority status category].freeze

    def initialize(upload)
      @upload = upload
    end

    def call
      return unless claim_upload!

      csv_content = download_file
      process_csv(csv_content)
      finalize!
    rescue CSV::MalformedCSVError => e
      fail_upload!("Invalid CSV format: #{e.message.truncate(200)}")
    rescue => e
      fail_upload!("Processing failed: #{e.message.truncate(200)}")
    end

    private

    attr_reader :upload

    def claim_upload!
      rows_affected = Upload.where(id: upload.id, status: "pending")
                            .update_all(status: "processing", updated_at: Time.current)
      rows_affected == 1
    end

    def download_file
      upload.file.download
    end

    def process_csv(content)
      rows = CSV.parse(content, headers: true, liberal_parsing: true)
      headers = rows.headers.map(&:to_s).map(&:strip)

      validate_headers!(headers)

      @total = rows.size
      @processed = 0
      @failed = 0

      upload.update!(total_records: @total)

      rows.each_slice(BATCH_SIZE) do |batch|
        process_batch(batch)
      end
    end

    def validate_headers!(headers)
      missing = REQUIRED_HEADERS - headers
      raise CSV::MalformedCSVError.new("Missing required columns: #{missing.join(', ')}", 1) if missing.any?
    end

    def process_batch(batch)
      ticket_attrs = []

      batch.each do |row|
        attrs = build_ticket_attrs(row)
        if attrs
          ticket_attrs << attrs
          @processed += 1
        else
          @failed += 1
        end
      end

      if ticket_attrs.any?
        analysis_attrs = ticket_attrs.map { |t| build_analysis_attrs(t) }

        ActiveRecord::Base.transaction do
          Ticket.insert_all(ticket_attrs)
          AiAnalysis.insert_all(analysis_attrs)
        end

        analysis_attrs.each do |attrs|
          AnalyzeTicketJob.perform_later(attrs[:id])
        end
      end

      upload.update!(processed_records: @processed, failed_records: @failed)
    end

    def build_ticket_attrs(row)
      subject = row["subject"]&.strip
      return nil if subject.blank?

      now = Time.current
      {
        id: SecureRandom.uuid,
        organization_id: upload.organization_id,
        upload_id: upload.id,
        subject: subject,
        description: row["description"]&.strip.presence,
        customer_name: row["customer_name"]&.strip.presence,
        customer_email: row["customer_email"]&.strip.presence,
        priority: row["priority"]&.strip.presence,
        status: row["status"]&.strip.presence,
        category: row["category"]&.strip.presence,
        created_at: now,
        updated_at: now
      }
    end

    def build_analysis_attrs(ticket_attrs)
      {
        id: SecureRandom.uuid,
        organization_id: ticket_attrs[:organization_id],
        ticket_id: ticket_attrs[:id],
        status: "pending",
        created_at: ticket_attrs[:created_at],
        updated_at: ticket_attrs[:updated_at]
      }
    end

    def finalize!
      upload.update!(status: "completed")
    end

    def fail_upload!(message)
      upload.update!(status: "failed", error_message: message)
    end
  end
end
