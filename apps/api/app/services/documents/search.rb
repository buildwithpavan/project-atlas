# frozen_string_literal: true

module Documents
  # Pure dense vector retrieval service.
  #
  # Takes a natural-language query, generates a query embedding using
  # the same model/dimensions as document embeddings, then performs
  # organization-scoped cosine similarity search via pgvector.
  #
  # Retrieval strategy (v1):
  #   1. Embed query → vector(1536) via text-embedding-3-small
  #   2. Retrieve initial_k nearest chunks (default 20) within the organization
  #   3. Convert cosine distance → similarity (1.0 - distance)
  #   4. Discard chunks below similarity_threshold (default 0.3)
  #   5. Return top final_k results (default 8) ordered by similarity descending
  #
  # Tenant isolation is enforced in SQL via WHERE organization_id = ?.
  # The query never touches chunks from other organizations.
  class Search < ApplicationService
    EMBEDDING_MODEL = "text-embedding-3-small"
    EMBEDDING_DIMENSIONS = 1536

    DEFAULT_INITIAL_K = 20
    DEFAULT_FINAL_K = 8
    DEFAULT_SIMILARITY_THRESHOLD = 0.3

    Result = Struct.new(
      :chunk, :chunk_id, :document_id, :document_title,
      :content, :similarity, :position, :metadata,
      keyword_init: true
    )

    def initialize(organization:, query:, initial_k: DEFAULT_INITIAL_K, final_k: DEFAULT_FINAL_K, similarity_threshold: DEFAULT_SIMILARITY_THRESHOLD)
      @organization = organization
      @query = query
      @initial_k = initial_k
      @final_k = final_k
      @similarity_threshold = similarity_threshold
    end

    def call
      validate_query!

      query_embedding = generate_query_embedding
      candidates = vector_search(query_embedding)
      build_results(candidates)
    end

    private

    def validate_query!
      if @query.blank?
        raise ValidationError.new(
          "Query cannot be blank",
          errors: { query: ["must be provided"] }
        )
      end
    end

    def generate_query_embedding
      embeddings = Ai::Providers::Openai.embed(
        texts: [@query],
        model: EMBEDDING_MODEL,
        dimensions: EMBEDDING_DIMENSIONS
      )
      embeddings.first
    end

    def vector_search(query_embedding)
      embedding_literal = "[#{query_embedding.join(',')}]"

      DocumentChunk
        .where(organization_id: @organization.id)
        .where.not(embedding: nil)
        .select(
          "document_chunks.*",
          Arel.sql(
            ApplicationRecord.sanitize_sql_array(
              ["embedding <=> ? AS cosine_distance", embedding_literal]
            )
          )
        )
        .includes(:document)
        .order(
          Arel.sql(
            ApplicationRecord.sanitize_sql_array(
              ["embedding <=> ?", embedding_literal]
            )
          )
        )
        .limit(@initial_k)
    end

    def build_results(candidates)
      candidates
        .filter_map { |chunk| build_result(chunk) }
        .sort_by { |r| -r.similarity }
        .first(@final_k)
    end

    def build_result(chunk)
      distance = chunk.read_attribute("cosine_distance").to_f
      similarity = 1.0 - distance

      return nil if similarity < @similarity_threshold

      Result.new(
        chunk: chunk,
        chunk_id: chunk.id,
        document_id: chunk.document_id,
        document_title: chunk.document&.title,
        content: chunk.content,
        similarity: similarity.round(4),
        position: chunk.position,
        metadata: chunk.metadata
      )
    end
  end
end
