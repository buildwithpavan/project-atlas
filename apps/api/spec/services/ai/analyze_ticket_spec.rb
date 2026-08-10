# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::AnalyzeTicket, type: :service do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme") }
  let(:upload) { Upload.create!(organization: organization, filename: "test.csv") }
  let(:ticket) { Ticket.create!(organization: organization, upload: upload, subject: "Help", description: "I need help with billing") }
  let(:ai_analysis) { AiAnalysis.create!(organization: organization, ticket: ticket) }

  let(:mock_result) do
    instance_double(
      Ai::Schemas::TicketAnalysis,
      sentiment: "negative",
      summary: "Customer needs help with billing",
      category: "billing",
      confidence: 0.92,
      feature_request: false,
      bug_report: false,
      knowledge_gap: true
    )
  end

  before do
    allow(Ai::Providers::Openai).to receive(:analyze).and_return(mock_result)
  end

  describe "successful analysis" do
    it "completes analysis with provider results" do
      described_class.call(ai_analysis)
      ai_analysis.reload

      expect(ai_analysis.status).to eq("completed")
      expect(ai_analysis.sentiment).to eq("negative")
      expect(ai_analysis.summary).to eq("Customer needs help with billing")
      expect(ai_analysis.category).to eq("billing")
      expect(ai_analysis.confidence).to eq(0.92)
      expect(ai_analysis.feature_request).to be(false)
      expect(ai_analysis.bug_report).to be(false)
      expect(ai_analysis.knowledge_gap).to be(true)
      expect(ai_analysis.processed_at).to be_present
    end

    it "calls the provider with the correct ticket" do
      described_class.call(ai_analysis)
      expect(Ai::Providers::Openai).to have_received(:analyze).with(ticket: ticket)
    end

    it "transitions status from pending through processing to completed" do
      expect(ai_analysis.status).to eq("pending")
      described_class.call(ai_analysis)
      expect(ai_analysis.reload.status).to eq("completed")
    end
  end

  describe "atomic claim" do
    it "claims a pending analysis and transitions to processing" do
      rows = AiAnalysis.where(id: ai_analysis.id, status: "pending")
                       .update_all(status: "processing", updated_at: Time.current)
      expect(rows).to eq(1)
      expect(ai_analysis.reload.status).to eq("processing")
    end

    it "prevents a second claim via atomic UPDATE" do
      AiAnalysis.where(id: ai_analysis.id, status: "pending")
                .update_all(status: "processing", updated_at: Time.current)

      rows = AiAnalysis.where(id: ai_analysis.id, status: "pending")
                       .update_all(status: "processing", updated_at: Time.current)
      expect(rows).to eq(0)
    end

    it "does not process an already-processing analysis" do
      ai_analysis.update!(status: "processing")
      described_class.call(ai_analysis)
      expect(ai_analysis.reload.status).to eq("processing")
    end

    it "does not process a completed analysis" do
      ai_analysis.update!(status: "completed", processed_at: Time.current)
      described_class.call(ai_analysis)
      expect(ai_analysis.reload.status).to eq("completed")
    end

    it "does not process a failed analysis" do
      ai_analysis.update!(status: "failed")
      described_class.call(ai_analysis)
      expect(ai_analysis.reload.status).to eq("failed")
    end
  end

  describe "failure handling" do
    it "marks analysis as failed when provider raises" do
      allow(Ai::Providers::Openai).to receive(:analyze).and_raise(StandardError, "API timeout")
      described_class.call(ai_analysis)
      ai_analysis.reload

      expect(ai_analysis.status).to eq("failed")
      expect(ai_analysis.error_message).to include("API timeout")
    end

    it "marks analysis as failed when provider returns invalid sentiment" do
      allow(mock_result).to receive(:sentiment).and_return("invalid_value")
      described_class.call(ai_analysis)
      ai_analysis.reload

      expect(ai_analysis.status).to eq("failed")
      expect(ai_analysis.error_message).to include("Invalid sentiment")
    end

    it "marks analysis as failed when confidence is out of range" do
      allow(mock_result).to receive(:confidence).and_return(1.5)
      described_class.call(ai_analysis)
      ai_analysis.reload

      expect(ai_analysis.status).to eq("failed")
      expect(ai_analysis.error_message).to include("Confidence out of range")
    end

    it "truncates long error messages" do
      allow(Ai::Providers::Openai).to receive(:analyze).and_raise(StandardError, "x" * 500)
      described_class.call(ai_analysis)
      ai_analysis.reload

      # "Analysis failed: " prefix (17 chars) + truncated message (200 chars max)
      expect(ai_analysis.error_message.length).to be <= 217
    end

    it "does not leave analysis stuck in processing after failure" do
      allow(Ai::Providers::Openai).to receive(:analyze).and_raise(StandardError, "boom")
      described_class.call(ai_analysis)
      expect(ai_analysis.reload.status).not_to eq("processing")
    end
  end

  describe "tenant integrity" do
    it "analysis remains associated with the correct ticket organization" do
      described_class.call(ai_analysis)
      expect(ai_analysis.reload.organization_id).to eq(ticket.organization_id)
    end
  end
end
