# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::ProcessDocument, type: :service do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme") }
  let(:user) { User.create!(email: "user@example.com", first_name: "A", last_name: "B", password: "password123") }
  let(:document) do
    doc = Document.create!(
      organization: organization,
      title: "Guide",
      filename: "guide.txt",
      content_type: "text/plain",
      file_size: 100,
      uploaded_by: user
    )
    doc.file.attach(io: StringIO.new("Hello world. This is a test document."), filename: "guide.txt", content_type: "text/plain")
    doc
  end

  let(:mock_embeddings) { [[0.1] * 1536] }

  before do
    allow(Ai::Providers::Openai).to receive(:embed).and_return(mock_embeddings)
  end

  describe "successful processing" do
    it "transitions document to completed" do
      described_class.call(document)
      expect(document.reload.status).to eq("completed")
    end

    it "extracts and persists text" do
      described_class.call(document)
      expect(document.reload.extracted_text).to eq("Hello world. This is a test document.")
    end

    it "creates document chunks" do
      described_class.call(document)
      expect(document.reload.chunk_count).to be >= 1
      expect(document.document_chunks.count).to eq(document.chunk_count)
    end

    it "stores embeddings on chunks" do
      described_class.call(document)
      chunk = document.document_chunks.reload.first
      expect(chunk).to be_present
      expect(chunk.embedding).to be_present
    end

    it "sets embedding_model" do
      described_class.call(document)
      expect(document.reload.embedding_model).to eq("text-embedding-3-small")
    end

    it "clears error_message on success" do
      document.update!(error_message: "Previous error")
      described_class.call(document)
      expect(document.reload.error_message).to be_nil
    end

    it "sets chunk positions sequentially" do
      allow(Ai::Providers::Openai).to receive(:embed) do |texts:, **|
        texts.map { [0.1] * 1536 }
      end

      large_text = ("Paragraph content. " * 200 + "\n\n") * 5
      doc = Document.create!(
        organization: organization, title: "Large", filename: "large.txt",
        content_type: "text/plain", file_size: large_text.bytesize
      )
      doc.file.attach(io: StringIO.new(large_text), filename: "large.txt", content_type: "text/plain")

      described_class.call(doc)
      positions = doc.document_chunks.order(:position).pluck(:position)
      expect(positions).to eq((0...positions.length).to_a)
    end

    it "assigns document's organization_id to all chunks" do
      described_class.call(document)
      org_ids = document.document_chunks.reload.pluck(:organization_id).uniq
      expect(org_ids).to eq([organization.id])
    end
  end

  describe "extraction reuse" do
    it "reuses existing extracted_text on reprocess" do
      document.update!(extracted_text: "Previously extracted text.")
      allow(Documents::TextExtractor).to receive(:call)

      described_class.call(document)

      expect(Documents::TextExtractor).not_to have_received(:call)
      expect(document.reload.extracted_text).to eq("Previously extracted text.")
    end
  end

  describe "reprocessing" do
    it "replaces existing chunks" do
      described_class.call(document)
      first_chunk_ids = document.document_chunks.reload.pluck(:id)
      expect(first_chunk_ids).not_to be_empty

      # Reset and reprocess
      document.update!(status: "pending")
      allow(Ai::Providers::Openai).to receive(:embed).and_return([[0.5] * 1536])

      described_class.call(document)
      new_chunk_ids = document.document_chunks.reload.pluck(:id)

      expect(new_chunk_ids).not_to be_empty
      expect(new_chunk_ids).not_to match_array(first_chunk_ids)
    end
  end

  describe "atomic claim" do
    it "claims a pending document" do
      described_class.call(document)
      expect(document.reload.status).to eq("completed")
    end

    it "does not process an already-processing document" do
      document.update!(status: "processing")
      described_class.call(document)
      # Status should remain processing (not changed by service)
      expect(document.reload.status).to eq("processing")
    end

    it "does not process a completed document" do
      document.update!(status: "completed")
      described_class.call(document)
      expect(document.reload.status).to eq("completed")
    end

    it "does not process a failed document" do
      document.update!(status: "failed")
      described_class.call(document)
      expect(document.reload.status).to eq("failed")
    end

    it "prevents concurrent processing via atomic UPDATE" do
      rows = Document.where(id: document.id, status: "pending")
                     .update_all(status: "processing", updated_at: Time.current)
      expect(rows).to eq(1)

      # Second claim attempt
      rows = Document.where(id: document.id, status: "pending")
                     .update_all(status: "processing", updated_at: Time.current)
      expect(rows).to eq(0)
    end
  end

  describe "empty content" do
    it "fails with useful error when no text is extractable" do
      empty_doc = Document.create!(
        organization: organization, title: "Empty", filename: "empty.txt",
        content_type: "text/plain", file_size: 0
      )
      empty_doc.file.attach(io: StringIO.new(""), filename: "empty.txt", content_type: "text/plain")

      described_class.call(empty_doc)
      empty_doc.reload
      expect(empty_doc.status).to eq("failed")
      expect(empty_doc.error_message).to include("No extractable text")
    end

    it "does not create chunks for empty content" do
      empty_doc = Document.create!(
        organization: organization, title: "Empty", filename: "empty.txt",
        content_type: "text/plain", file_size: 0
      )
      empty_doc.file.attach(io: StringIO.new("   "), filename: "empty.txt", content_type: "text/plain")

      described_class.call(empty_doc)
      expect(empty_doc.document_chunks.count).to eq(0)
    end

    it "does not call embedding API for empty content" do
      empty_doc = Document.create!(
        organization: organization, title: "Empty", filename: "empty.txt",
        content_type: "text/plain", file_size: 0
      )
      empty_doc.file.attach(io: StringIO.new(""), filename: "empty.txt", content_type: "text/plain")

      described_class.call(empty_doc)
      expect(Ai::Providers::Openai).not_to have_received(:embed)
    end
  end

  describe "transient errors" do
    it "resets document to pending on network timeout" do
      allow(Ai::Providers::Openai).to receive(:embed).and_raise(Net::ReadTimeout)

      expect {
        described_class.call(document)
      }.to raise_error(Net::ReadTimeout)

      expect(document.reload.status).to eq("pending")
    end

    it "resets document to pending on connection refused" do
      allow(Ai::Providers::Openai).to receive(:embed).and_raise(Errno::ECONNREFUSED)

      expect {
        described_class.call(document)
      }.to raise_error(Errno::ECONNREFUSED)

      expect(document.reload.status).to eq("pending")
    end

    it "resets document to pending on Faraday timeout" do
      allow(Ai::Providers::Openai).to receive(:embed).and_raise(OpenAI::Errors::APITimeoutError.new(url: "https://api.openai.com", message: "timeout"))

      expect {
        described_class.call(document)
      }.to raise_error(OpenAI::Errors::APITimeoutError)

      expect(document.reload.status).to eq("pending")
    end
  end

  describe "permanent errors" do
    it "marks document as failed on extraction error" do
      bad_doc = Document.create!(
        organization: organization, title: "Bad", filename: "bad.bin",
        content_type: "application/octet-stream", file_size: 10
      )
      bad_doc.file.attach(io: StringIO.new("binary"), filename: "bad.bin", content_type: "application/octet-stream")

      described_class.call(bad_doc)
      bad_doc.reload
      expect(bad_doc.status).to eq("failed")
      expect(bad_doc.error_message).to include("Processing failed")
    end

    it "does not re-raise permanent errors" do
      allow(Documents::TextExtractor).to receive(:call).and_raise(RuntimeError, "corrupt file")

      expect { described_class.call(document) }.not_to raise_error
      expect(document.reload.status).to eq("failed")
    end
  end

  describe "batch embedding" do
    it "calls embed with all chunk contents at once for small documents" do
      described_class.call(document)
      expect(Ai::Providers::Openai).to have_received(:embed).with(
        texts: anything,
        model: "text-embedding-3-small",
        dimensions: 1536
      )
    end

    it "batches embedding requests for large documents" do
      allow(Ai::Providers::Openai).to receive(:embed) do |texts:, **|
        texts.map { [0.1] * 1536 }
      end

      # Create a document that produces many chunks
      large_text = (1..150).map { |i| "Section #{i}. " + ("Content for section #{i}. " * 30) + "\n\n" }.join
      large_doc = Document.create!(
        organization: organization, title: "Large", filename: "large.txt",
        content_type: "text/plain", file_size: large_text.bytesize
      )
      large_doc.file.attach(io: StringIO.new(large_text), filename: "large.txt", content_type: "text/plain")

      described_class.call(large_doc)

      # Should have made at least 1 embed call
      expect(Ai::Providers::Openai).to have_received(:embed).at_least(:once)
      expect(large_doc.reload.status).to eq("completed")
      expect(large_doc.chunk_count).to be > 0
    end
  end
end
