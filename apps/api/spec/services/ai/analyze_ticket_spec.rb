# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::AnalyzeTicket, type: :service do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme") }
  let(:upload) { Upload.create!(organization: organization, filename: "test.csv") }
  let(:ticket) { Ticket.create!(organization: organization, upload: upload, subject: "Help") }
  let(:ai_analysis) { AiAnalysis.create!(organization: organization, ticket: ticket) }

  describe "atomic claim" do
    it "claims a pending analysis and transitions to processing" do
      rows = AiAnalysis.where(id: ai_analysis.id, status: "pending")
                       .update_all(status: "processing", updated_at: Time.current)
      expect(rows).to eq(1)
      expect(ai_analysis.reload.status).to eq("processing")
    end

    it "prevents a second claim via atomic UPDATE" do
      # First claim
      AiAnalysis.where(id: ai_analysis.id, status: "pending")
                .update_all(status: "processing", updated_at: Time.current)

      # Second claim attempt
      rows = AiAnalysis.where(id: ai_analysis.id, status: "pending")
                       .update_all(status: "processing", updated_at: Time.current)
      expect(rows).to eq(0)
    end

    it "does not process an already-processing analysis" do
      ai_analysis.update!(status: "processing")
      described_class.call(ai_analysis)
      # Should return without changing state (claim fails)
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
      # The current implementation raises NotImplementedError (provider not yet integrated)
      described_class.call(ai_analysis)
      ai_analysis.reload
      expect(ai_analysis.status).to eq("failed")
      expect(ai_analysis.error_message).to include("not yet implemented")
    end

    it "does not leave analysis stuck in processing after failure" do
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
