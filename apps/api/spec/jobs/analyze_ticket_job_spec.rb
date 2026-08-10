# frozen_string_literal: true

require "rails_helper"

RSpec.describe AnalyzeTicketJob, type: :job do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme") }
  let(:upload) { Upload.create!(organization: organization, filename: "test.csv") }
  let(:ticket) { Ticket.create!(organization: organization, upload: upload, subject: "Help") }
  let(:ai_analysis) { AiAnalysis.create!(organization: organization, ticket: ticket) }

  it "calls Ai::AnalyzeTicket with the analysis" do
    expect(Ai::AnalyzeTicket).to receive(:call).with(ai_analysis)
    described_class.perform_now(ai_analysis)
  end

  it "handles the analysis lifecycle" do
    described_class.perform_now(ai_analysis)
    # Currently fails gracefully since provider isn't implemented
    expect(ai_analysis.reload.status).to eq("failed")
  end
end
