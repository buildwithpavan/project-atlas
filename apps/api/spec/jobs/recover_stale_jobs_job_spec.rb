# frozen_string_literal: true

require "rails_helper"
require "ostruct"

RSpec.describe RecoverStaleJobsJob, type: :job do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme") }
  let(:upload) { Upload.create!(organization: organization, filename: "test.csv") }

  def create_ticket_with_analysis(status:, updated_at: Time.current)
    ticket = Ticket.create!(organization: organization, upload: upload, subject: "Test")
    analysis = AiAnalysis.create!(organization: organization, ticket: ticket, status: status)
    analysis.update_columns(updated_at: updated_at)
    analysis
  end

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  describe "stale AI analysis recovery" do
    it "resets stale processing analyses to pending" do
      analysis = create_ticket_with_analysis(status: "processing", updated_at: 15.minutes.ago)

      described_class.perform_now
      expect(analysis.reload.status).to eq("pending")
    end

    it "re-enqueues recovered analyses" do
      analysis = create_ticket_with_analysis(status: "processing", updated_at: 15.minutes.ago)

      described_class.perform_now
      expect(AnalyzeTicketJob).to have_been_enqueued.with(analysis.id)
    end

    it "does not touch recently started processing analyses" do
      analysis = create_ticket_with_analysis(status: "processing", updated_at: 2.minutes.ago)

      described_class.perform_now
      expect(analysis.reload.status).to eq("processing")
    end

    it "does not touch pending analyses" do
      analysis = create_ticket_with_analysis(status: "pending", updated_at: 15.minutes.ago)

      described_class.perform_now
      expect(analysis.reload.status).to eq("pending")
      expect(AnalyzeTicketJob).not_to have_been_enqueued
    end

    it "does not touch completed analyses" do
      analysis = create_ticket_with_analysis(status: "completed", updated_at: 15.minutes.ago)

      described_class.perform_now
      expect(analysis.reload.status).to eq("completed")
    end

    it "does not touch failed analyses" do
      analysis = create_ticket_with_analysis(status: "failed", updated_at: 15.minutes.ago)

      described_class.perform_now
      expect(analysis.reload.status).to eq("failed")
    end

    it "recovered analysis can be processed again" do
      analysis = create_ticket_with_analysis(status: "processing", updated_at: 15.minutes.ago)

      described_class.perform_now
      expect(analysis.reload.status).to eq("pending")

      # Simulate the re-enqueued job claiming and completing
      mock_result = OpenStruct.new(
        sentiment: "neutral", summary: "Test", category: "general",
        confidence: 0.8, feature_request: false, bug_report: false, knowledge_gap: false
      )
      allow(Ai::Providers::Openai).to receive(:analyze).and_return(mock_result)
      allow(Ai::Providers::Atlas).to receive(:analyze).and_return(mock_result)

      Ai::AnalyzeTicket.call(analysis)
      expect(analysis.reload.status).to eq("completed")
    end

    it "handles multiple stale analyses" do
      a1 = create_ticket_with_analysis(status: "processing", updated_at: 20.minutes.ago)
      a2 = create_ticket_with_analysis(status: "processing", updated_at: 15.minutes.ago)
      a3 = create_ticket_with_analysis(status: "processing", updated_at: 2.minutes.ago) # recent

      described_class.perform_now

      expect(a1.reload.status).to eq("pending")
      expect(a2.reload.status).to eq("pending")
      expect(a3.reload.status).to eq("processing")
    end
  end

  describe "stale upload recovery" do
    it "marks stale processing uploads as failed" do
      stale_upload = Upload.create!(organization: organization, filename: "stale.csv", status: "processing")
      stale_upload.update_columns(updated_at: 15.minutes.ago)

      described_class.perform_now
      expect(stale_upload.reload.status).to eq("failed")
      expect(stale_upload.error_message).to include("timed out")
    end

    it "does not touch recently started processing uploads" do
      recent_upload = Upload.create!(organization: organization, filename: "recent.csv", status: "processing")
      recent_upload.update_columns(updated_at: 2.minutes.ago)

      described_class.perform_now
      expect(recent_upload.reload.status).to eq("processing")
    end

    it "does not touch pending uploads" do
      pending_upload = Upload.create!(organization: organization, filename: "pending.csv", status: "pending")
      pending_upload.update_columns(updated_at: 15.minutes.ago)

      described_class.perform_now
      expect(pending_upload.reload.status).to eq("pending")
    end
  end

  describe "idempotency" do
    it "is safe to run multiple times" do
      analysis = create_ticket_with_analysis(status: "processing", updated_at: 15.minutes.ago)

      described_class.perform_now
      expect(analysis.reload.status).to eq("pending")

      # Running again should be a no-op since it's now pending, not processing
      described_class.perform_now
      expect(analysis.reload.status).to eq("pending")
    end
  end

  describe "stale document recovery" do
    def create_document(status:, updated_at: Time.current)
      doc = Document.create!(
        organization: organization, title: "Test", filename: "test.txt",
        content_type: "text/plain", file_size: 100, status: status
      )
      doc.update_columns(updated_at: updated_at)
      doc
    end

    it "resets stale processing documents to pending" do
      doc = create_document(status: "processing", updated_at: 15.minutes.ago)

      described_class.perform_now
      expect(doc.reload.status).to eq("pending")
    end

    it "re-enqueues recovered documents" do
      doc = create_document(status: "processing", updated_at: 15.minutes.ago)

      described_class.perform_now
      expect(ProcessDocumentJob).to have_been_enqueued
    end

    it "does not touch recently started processing documents" do
      doc = create_document(status: "processing", updated_at: 2.minutes.ago)

      described_class.perform_now
      expect(doc.reload.status).to eq("processing")
    end

    it "does not touch pending documents" do
      doc = create_document(status: "pending", updated_at: 15.minutes.ago)

      described_class.perform_now
      expect(doc.reload.status).to eq("pending")
      expect(ProcessDocumentJob).not_to have_been_enqueued
    end

    it "does not touch completed documents" do
      doc = create_document(status: "completed", updated_at: 15.minutes.ago)

      described_class.perform_now
      expect(doc.reload.status).to eq("completed")
    end

    it "does not touch failed documents" do
      doc = create_document(status: "failed", updated_at: 15.minutes.ago)

      described_class.perform_now
      expect(doc.reload.status).to eq("failed")
    end

    it "only re-enqueues documents that were actually reset to pending" do
      doc1 = create_document(status: "processing", updated_at: 15.minutes.ago)
      doc2 = create_document(status: "processing", updated_at: 15.minutes.ago)

      described_class.perform_now

      expect(doc1.reload.status).to eq("pending")
      expect(doc2.reload.status).to eq("pending")
      expect(ProcessDocumentJob).to have_been_enqueued.at_least(:twice)
    end
  end
end
