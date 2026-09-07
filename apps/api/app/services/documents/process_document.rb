# frozen_string_literal: true

module Documents
  # Processes a document through the full pipeline:
  #   pending → processing → extract text → chunk → embed → completed
  #
  # Uses atomic claiming (UPDATE WHERE status=pending) to prevent duplicate
  # processing. Follows the same transient/permanent error pattern as
  # Ai::AnalyzeTicket.
  #
  # Error handling:
  #   - Transient errors (OpenAI timeout, rate limit, network) reset the
  #     document to pending and re-raise so Active Job can retry.
  #   - Permanent errors (unsupported file, extraction failure) transition
  #     the document to failed with an error message.
  class ProcessDocument < ApplicationService
    EMBEDDING_MODEL = "text-embedding-3-small"
    EMBEDDING_DIMENSIONS = 1536
    EMBEDDING_BATCH_SIZE = 100

    TRANSIENT_ERRORS = [
      Net::OpenTimeout,
      Net::ReadTimeout,
      Errno::ECONNREFUSED,
      OpenAI::Errors::APIConnectionError,
      OpenAI::Errors::APITimeoutError,
      OpenAI::Errors::RateLimitError,
      OpenAI::Errors::InternalServerError
    ].freeze

    def initialize(document)
      @document = document
    end

    def call
      return unless claim!

      process
    rescue *TRANSIENT_ERRORS => e
      reset_to_pending!
      raise
    rescue StandardError => e
      fail_document!("Processing failed: #{e.message.truncate(200)}")
    end

    private

    attr_reader :document

    def claim!
      rows_affected = Document.where(id: document.id, status: "pending")
                              .update_all(status: "processing", updated_at: Time.current)
      rows_affected == 1
    end

    def process
      # Extract text (reuse existing extracted_text on reprocess)
      text = document.extracted_text.presence || Documents::TextExtractor.call(document)

      if text.blank?
        fail_document!("No extractable text found in document.")
        return
      end

      # Persist extracted_text if not already saved
      document.update!(extracted_text: text) unless document.extracted_text.present?

      # Chunk the text
      chunks = Documents::Chunker.call(text)

      if chunks.empty?
        fail_document!("No extractable text found in document.")
        return
      end

      # Generate embeddings in batches
      embeddings = generate_embeddings(chunks)

      # Persist chunks and update document atomically
      persist_chunks_and_complete!(chunks, embeddings)
    end

    def generate_embeddings(chunks)
      all_embeddings = []

      chunks.each_slice(EMBEDDING_BATCH_SIZE) do |batch|
        texts = batch.map(&:content)
        batch_embeddings = Ai::Providers::Openai.embed(
          texts: texts,
          model: EMBEDDING_MODEL,
          dimensions: EMBEDDING_DIMENSIONS
        )
        all_embeddings.concat(batch_embeddings)
      end

      all_embeddings
    end

    def persist_chunks_and_complete!(chunks, embeddings)
      now = Time.current

      Document.transaction do
        # Delete existing chunks (idempotent for reprocessing)
        document.document_chunks.delete_all

        # Build chunk records for bulk insertion
        chunk_records = chunks.each_with_index.map do |chunk, index|
          {
            id: SecureRandom.uuid,
            organization_id: document.organization_id,
            document_id: document.id,
            content: chunk.content,
            position: chunk.position,
            token_count: chunk.token_count,
            embedding: "[#{embeddings[index].join(',')}]",
            metadata: chunk.metadata.to_json,
            created_at: now
          }
        end

        DocumentChunk.insert_all(chunk_records) if chunk_records.any?

        document.update!(
          chunk_count: chunks.length,
          embedding_model: EMBEDDING_MODEL,
          status: "completed",
          error_message: nil
        )
      end
    end

    def fail_document!(message)
      document.update!(status: "failed", error_message: message)
    end

    def reset_to_pending!
      Document.where(id: document.id, status: "processing")
              .update_all(status: "pending", updated_at: Time.current)
    end
  end
end
