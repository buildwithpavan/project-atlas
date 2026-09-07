# frozen_string_literal: true

module Documents
  class TextExtractor < ApplicationService
    SUPPORTED_CONTENT_TYPES = {
      "application/pdf" => :extract_pdf,
      "text/plain" => :extract_text,
      "text/markdown" => :extract_text,
      "text/x-markdown" => :extract_text,
      "text/csv" => :extract_csv
    }.freeze

    def initialize(document)
      @document = document
    end

    def call
      method = SUPPORTED_CONTENT_TYPES[@document.content_type]

      unless method
        raise ValidationError.new(
          "Unsupported content type: #{@document.content_type}",
          errors: { content_type: [ "#{@document.content_type} is not supported for text extraction" ] }
        )
      end

      send(method)
    end

    private

    def extract_pdf
      reader = PDF::Reader.new(file_io)
      reader.pages.map(&:text).join("\n\n")
    end

    def extract_text
      file_io.read.force_encoding("UTF-8")
    end

    def extract_csv
      content = file_io.read.force_encoding("UTF-8")
      csv = CSV.parse(content, headers: true, liberal_parsing: true)

      return content if csv.headers.compact.empty?

      csv.map { |row|
        csv.headers.compact.map { |header| "#{header}: #{row[header]}" }.join(", ")
      }.join("\n")
    end

    def file_io
      @file_io ||= if @document.file.attached?
        StringIO.new(@document.file.download)
      else
        raise ValidationError.new(
          "No file attached to document",
          errors: { file: [ "must be attached before text extraction" ] }
        )
      end
    end
  end
end
