# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::Search, type: :service do
  let(:org_a) { Organization.create!(name: "Org A", slug: "org-a") }
  let(:org_b) { Organization.create!(name: "Org B", slug: "org-b") }

  # Deterministic unit vectors for testing cosine similarity.
  # Cosine distance between identical vectors = 0.0 → similarity = 1.0
  # Cosine distance between orthogonal vectors = 1.0 → similarity = 0.0
  #
  # We build vectors that produce known cosine distances when compared
  # via pgvector's <=> operator.

  # Query vector: unit vector along dimension 0
  let(:query_vector) do
    v = [0.0] * 1536
    v[0] = 1.0
    v
  end

  # Very similar to query (cosine distance ≈ 0.005, similarity ≈ 0.995)
  let(:very_similar_vector) do
    v = [0.0] * 1536
    v[0] = 0.99
    v[1] = 0.1
    v
  end

  # Moderately similar (cosine distance ≈ 0.29, similarity ≈ 0.71)
  let(:moderately_similar_vector) do
    v = [0.0] * 1536
    v[0] = 0.7
    v[1] = 0.7
    v
  end

  # Weakly similar (cosine distance ≈ 0.69, similarity ≈ 0.31)
  let(:weakly_similar_vector) do
    v = [0.0] * 1536
    v[0] = 0.3
    v[1] = 0.95
    v
  end

  # Below threshold (cosine distance > 0.7, similarity < 0.3)
  let(:dissimilar_vector) do
    v = [0.0] * 1536
    v[0] = 0.1
    v[1] = 1.0
    v
  end

  # Orthogonal (cosine distance = 1.0, similarity = 0.0)
  let(:orthogonal_vector) do
    v = [0.0] * 1536
    v[1] = 1.0
    v
  end

  before do
    allow(Ai::Providers::Openai).to receive(:embed)
      .with(texts: ["test query"], model: "text-embedding-3-small", dimensions: 1536)
      .and_return([query_vector])
  end

  def create_doc(org:, title: "Doc")
    Document.create!(
      organization: org, title: title, filename: "#{title.parameterize}.txt",
      content_type: "text/plain", file_size: 100, status: "completed"
    )
  end

  def create_chunk(doc:, position:, embedding:, content: "Chunk #{position}")
    embedding_str = "[#{embedding.join(',')}]"
    DocumentChunk.connection.execute(
      ApplicationRecord.sanitize_sql_array([
        "INSERT INTO document_chunks (id, organization_id, document_id, content, position, token_count, embedding, metadata, created_at) VALUES (gen_random_uuid(), ?, ?, ?, ?, 10, ?, '{}', NOW())",
        doc.organization_id, doc.id, content, position, embedding_str
      ])
    )
    DocumentChunk.find_by!(document_id: doc.id, position: position)
  end

  def search(org: org_a, query: "test query", **opts)
    described_class.call(organization: org, query: query, **opts)
  end

  # ── Query Embedding ──────────────────────────────────────────────────

  describe "query embedding" do
    let!(:doc) { create_doc(org: org_a) }
    let!(:chunk) { create_chunk(doc: doc, position: 0, embedding: very_similar_vector) }

    it "calls Ai::Providers::Openai.embed with the query" do
      search
      expect(Ai::Providers::Openai).to have_received(:embed).with(
        texts: ["test query"],
        model: "text-embedding-3-small",
        dimensions: 1536
      )
    end

    it "uses text-embedding-3-small model" do
      search
      expect(Ai::Providers::Openai).to have_received(:embed).with(
        hash_including(model: "text-embedding-3-small")
      )
    end

    it "uses 1536 dimensions" do
      search
      expect(Ai::Providers::Openai).to have_received(:embed).with(
        hash_including(dimensions: 1536)
      )
    end
  end

  # ── Blank Query ──────────────────────────────────────────────────────

  describe "blank query" do
    it "raises ValidationError for nil query" do
      expect { search(query: nil) }.to raise_error(ValidationError, /blank/)
    end

    it "raises ValidationError for empty string" do
      expect { search(query: "") }.to raise_error(ValidationError, /blank/)
    end

    it "raises ValidationError for whitespace-only query" do
      expect { search(query: "   ") }.to raise_error(ValidationError, /blank/)
    end

    it "does not call OpenAI for blank query" do
      search(query: "") rescue nil
      expect(Ai::Providers::Openai).not_to have_received(:embed)
    end
  end

  # ── Vector Search + Similarity ───────────────────────────────────────

  describe "vector search and similarity" do
    let!(:doc) { create_doc(org: org_a, title: "KB Article") }

    it "returns results sorted by similarity descending" do
      c1 = create_chunk(doc: doc, position: 0, embedding: moderately_similar_vector, content: "Moderate")
      c2 = create_chunk(doc: doc, position: 1, embedding: very_similar_vector, content: "Very similar")

      results = search
      expect(results.length).to eq(2)
      expect(results[0].content).to eq("Very similar")
      expect(results[1].content).to eq("Moderate")
      expect(results[0].similarity).to be > results[1].similarity
    end

    it "calculates similarity as 1.0 - cosine_distance" do
      create_chunk(doc: doc, position: 0, embedding: very_similar_vector)

      results = search
      expect(results.first.similarity).to be_between(0.99, 1.0)
    end

    it "returns similarity close to 0 for orthogonal vectors" do
      create_chunk(doc: doc, position: 0, embedding: orthogonal_vector)

      results = search(similarity_threshold: 0.0)
      expect(results.first.similarity).to be_between(-0.01, 0.01)
    end
  end

  # ── Similarity Threshold ─────────────────────────────────────────────

  describe "similarity threshold" do
    let!(:doc) { create_doc(org: org_a) }

    it "excludes results below the default threshold (0.3)" do
      create_chunk(doc: doc, position: 0, embedding: very_similar_vector)
      create_chunk(doc: doc, position: 1, embedding: dissimilar_vector)
      create_chunk(doc: doc, position: 2, embedding: orthogonal_vector)

      results = search
      results.each do |r|
        expect(r.similarity).to be >= 0.3
      end
    end

    it "accepts custom similarity threshold" do
      create_chunk(doc: doc, position: 0, embedding: very_similar_vector)
      create_chunk(doc: doc, position: 1, embedding: moderately_similar_vector)

      results = search(similarity_threshold: 0.9)
      expect(results.length).to eq(1)
      expect(results.first.similarity).to be >= 0.9
    end

    it "returns fewer results when most are below threshold" do
      create_chunk(doc: doc, position: 0, embedding: dissimilar_vector)
      create_chunk(doc: doc, position: 1, embedding: orthogonal_vector)
      create_chunk(doc: doc, position: 2, embedding: very_similar_vector)

      results = search
      expect(results.length).to eq(1)
    end
  end

  # ── Top-K ────────────────────────────────────────────────────────────

  describe "top-K limits" do
    let!(:doc) { create_doc(org: org_a) }

    it "returns at most final_k results (default 8)" do
      12.times do |i|
        # Create vectors very similar to query
        v = [0.0] * 1536
        v[0] = 0.95 + (i * 0.001)
        v[1] = 0.05
        create_chunk(doc: doc, position: i, embedding: v)
      end

      results = search
      expect(results.length).to eq(8)
    end

    it "supports custom final_k" do
      5.times do |i|
        v = [0.0] * 1536
        v[0] = 0.95 + (i * 0.001)
        v[1] = 0.05
        create_chunk(doc: doc, position: i, embedding: v)
      end

      results = search(final_k: 3)
      expect(results.length).to eq(3)
    end

    it "returns fewer than final_k when fewer pass threshold" do
      create_chunk(doc: doc, position: 0, embedding: very_similar_vector)
      create_chunk(doc: doc, position: 1, embedding: orthogonal_vector)

      results = search
      expect(results.length).to eq(1)
    end

    it "initial_k limits the candidate pool" do
      5.times do |i|
        v = [0.0] * 1536
        v[0] = 0.9 + (i * 0.01)
        v[1] = 0.1
        create_chunk(doc: doc, position: i, embedding: v)
      end

      results = search(initial_k: 2, final_k: 10)
      expect(results.length).to eq(2)
    end
  end

  # ── Result Structure ─────────────────────────────────────────────────

  describe "result structure" do
    let!(:doc) { create_doc(org: org_a, title: "Refund Policy") }

    it "returns Result objects with all expected fields" do
      chunk = create_chunk(doc: doc, position: 4, embedding: very_similar_vector, content: "Customers may request...")

      results = search
      r = results.first
      expect(r).to be_a(Documents::Search::Result)
      expect(r.chunk_id).to eq(chunk.id)
      expect(r.document_id).to eq(doc.id)
      expect(r.document_title).to eq("Refund Policy")
      expect(r.content).to eq("Customers may request...")
      expect(r.similarity).to be_a(Float)
      expect(r.position).to eq(4)
      expect(r.metadata).to be_a(Hash)
      expect(r.chunk).to be_a(DocumentChunk)
    end
  end

  # ── Document Association ─────────────────────────────────────────────

  describe "document association" do
    it "eager loads document to avoid N+1" do
      doc = create_doc(org: org_a, title: "Loaded Doc")
      create_chunk(doc: doc, position: 0, embedding: very_similar_vector)

      results = search
      # Document should already be loaded — no additional query
      expect(results.first.document_title).to eq("Loaded Doc")
      expect(results.first.chunk.association(:document)).to be_loaded
    end
  end

  # ── No Searchable Chunks ─────────────────────────────────────────────

  describe "no searchable chunks" do
    it "returns empty array when organization has no chunks" do
      results = search
      expect(results).to eq([])
    end

    it "returns empty array when all chunks have nil embedding" do
      doc = create_doc(org: org_a)
      # Insert chunk without embedding
      DocumentChunk.connection.execute(
        ApplicationRecord.sanitize_sql_array([
          "INSERT INTO document_chunks (id, organization_id, document_id, content, position, token_count, metadata, created_at) VALUES (gen_random_uuid(), ?, ?, 'No embedding', 0, 10, '{}', NOW())",
          org_a.id, doc.id
        ])
      )

      results = search
      expect(results).to eq([])
    end
  end

  # ── Organization Isolation ───────────────────────────────────────────

  describe "organization isolation" do
    let!(:doc_a) { create_doc(org: org_a, title: "Org A Doc") }
    let!(:doc_b) { create_doc(org: org_b, title: "Org B Doc") }

    before do
      # Org A has a moderately similar chunk
      create_chunk(doc: doc_a, position: 0, embedding: moderately_similar_vector, content: "Org A content")
      # Org B has a MORE similar chunk — must never appear in Org A's results
      create_chunk(doc: doc_b, position: 0, embedding: very_similar_vector, content: "Org B secret content")
    end

    it "only returns chunks belonging to the searched organization" do
      results = search(org: org_a)
      expect(results.length).to eq(1)
      expect(results.first.content).to eq("Org A content")
    end

    it "never returns chunks from another organization even if more similar" do
      results = search(org: org_a)
      contents = results.map(&:content)
      expect(contents).not_to include("Org B secret content")
    end

    it "Org B's highly similar chunk does not influence Org A results" do
      results = search(org: org_a)
      expect(results.map(&:chunk_id)).to all(
        satisfy { |id| DocumentChunk.find(id).organization_id == org_a.id }
      )
    end

    it "searching Org B returns only Org B chunks" do
      allow(Ai::Providers::Openai).to receive(:embed)
        .with(texts: ["test query"], model: "text-embedding-3-small", dimensions: 1536)
        .and_return([query_vector])

      results = search(org: org_b)
      expect(results.length).to eq(1)
      expect(results.first.content).to eq("Org B secret content")
    end

    it "all result organization_ids match the queried organization" do
      results = search(org: org_a)
      results.each do |r|
        expect(r.chunk.organization_id).to eq(org_a.id)
      end
    end
  end

  # ── Cross-Tenant Data Integrity ──────────────────────────────────────

  describe "cross-tenant data integrity" do
    it "composite FK prevents a chunk from referencing a document in another organization" do
      doc_b = create_doc(org: org_b, title: "Org B Doc")

      expect {
        DocumentChunk.connection.execute(
          ApplicationRecord.sanitize_sql_array([
            "INSERT INTO document_chunks (id, organization_id, document_id, content, position, token_count, metadata, created_at) VALUES (gen_random_uuid(), ?, ?, 'Cross-tenant', 0, 10, '{}', NOW())",
            org_a.id, doc_b.id
          ])
        )
      }.to raise_error(ActiveRecord::StatementInvalid, /violates foreign key constraint "fk_document_chunks_organization_document"/)
    end
  end

  # ── OpenAI Failure ───────────────────────────────────────────────────

  describe "OpenAI failure" do
    before do
      allow(Ai::Providers::Openai).to receive(:embed)
        .and_raise(OpenAI::Errors::APIConnectionError.new(url: "https://api.openai.com", message: "connection failed"))
    end

    it "propagates the error without performing vector search" do
      expect {
        search
      }.to raise_error(OpenAI::Errors::APIConnectionError)
    end

    it "does not return fake results" do
      results = search rescue nil
      expect(results).to be_nil
    end
  end
end
