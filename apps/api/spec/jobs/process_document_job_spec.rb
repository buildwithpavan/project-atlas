# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProcessDocumentJob, type: :job do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme") }
  let(:document) do
    doc = Document.create!(
      organization: organization,
      title: "Guide",
      filename: "guide.txt",
      content_type: "text/plain",
      file_size: 100
    )
    doc.file.attach(io: StringIO.new("Hello world"), filename: "guide.txt", content_type: "text/plain")
    doc
  end

  before do
    allow(Ai::Providers::Openai).to receive(:embed).and_return([[0.1] * 1536])
  end

  it "calls Documents::ProcessDocument with the document" do
    expect(Documents::ProcessDocument).to receive(:call).with(document)
    described_class.perform_now(document)
  end

  it "processes the document successfully" do
    described_class.perform_now(document)
    expect(document.reload.status).to eq("completed")
  end

  describe "queue configuration" do
    it "uses the import queue" do
      expect(described_class.new.queue_name).to eq("import")
    end
  end

  describe "retry configuration" do
    it "has retry handlers for transient errors" do
      retried_errors = described_class.rescue_handlers.map(&:first)

      expect(retried_errors).to include("Net::OpenTimeout")
      expect(retried_errors).to include("Net::ReadTimeout")
      expect(retried_errors).to include("Errno::ECONNREFUSED")
      expect(retried_errors).to include("OpenAI::Errors::APIConnectionError")
      expect(retried_errors).to include("OpenAI::Errors::APITimeoutError")
      expect(retried_errors).to include("OpenAI::Errors::RateLimitError")
    end
  end
end
