# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::Schemas::TicketAnalysis, type: :service do
  it "is a subclass of OpenAI::BaseModel" do
    expect(described_class).to be < OpenAI::BaseModel
  end

  it "defines the expected fields" do
    schema = described_class
    expect(schema.known_fields.keys).to contain_exactly(
      :sentiment, :summary, :category, :confidence,
      :feature_request, :bug_report, :knowledge_gap
    )
  end
end
