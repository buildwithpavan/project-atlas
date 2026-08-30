# frozen_string_literal: true

require "rails_helper"

RSpec.describe AnalyzeTicketJob, type: :job do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme") }
  let(:upload) { Upload.create!(organization: organization, filename: "test.csv") }
  let(:ticket) { Ticket.create!(organization: organization, upload: upload, subject: "Help", description: "I need assistance") }
  let(:ai_analysis) { AiAnalysis.create!(organization: organization, ticket: ticket) }

  let(:mock_result) do
    instance_double(
      Ai::Schemas::TicketAnalysis,
      sentiment: "neutral",
      summary: "Customer needs assistance",
      category: "general",
      confidence: 0.85,
      feature_request: false,
      bug_report: false,
      knowledge_gap: false
    )
  end

  before do
    allow(Ai::Providers::Openai).to receive(:analyze).and_return(mock_result)
    allow(Ai::Providers::Atlas).to receive(:analyze).and_return(mock_result)
  end

  it "finds the analysis by ID and calls Ai::AnalyzeTicket" do
    expect(Ai::AnalyzeTicket).to receive(:call).with(ai_analysis)
    described_class.perform_now(ai_analysis.id)
  end

  it "completes the analysis successfully" do
    described_class.perform_now(ai_analysis.id)
    expect(ai_analysis.reload.status).to eq("completed")
  end

  it "raises ActiveRecord::RecordNotFound for unknown ID" do
    expect { described_class.perform_now(SecureRandom.uuid) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  describe "queue configuration" do
    it "uses the analysis queue" do
      expect(described_class.new.queue_name).to eq("analysis")
    end
  end

  describe "retry configuration" do
    it "has retry handlers for transient AI service errors" do
      retried_errors = described_class.rescue_handlers.map(&:first)

      expect(retried_errors).to include("Ai::Client::ConnectionError")
      expect(retried_errors).to include("Ai::Client::TimeoutError")
      expect(retried_errors).to include("Ai::Client::HttpError")
    end
  end
end
