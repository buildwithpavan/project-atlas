# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::HealthCheck, type: :service do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme") }
  let(:user) do
    User.create!(email: "user@example.com", first_name: "A", last_name: "B", password: "password123")
  end
  let!(:membership) { Membership.create!(user: user, organization: organization, role: "member") }

  before do
    # Default: API key is configured
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("sk-test-key")
  end

  describe "#call" do
    it "returns operational when no issues" do
      result = described_class.call(organization: organization)
      expect(result.status).to eq(:operational)
      expect(result.message).to include("operating normally")
      expect(result.configuration_valid).to be true
    end

    it "returns configuration_missing when API key is not set" do
      allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return(nil)

      result = described_class.call(organization: organization)
      expect(result.status).to eq(:configuration_missing)
      expect(result.message).to include("OPENAI_API_KEY")
      expect(result.configuration_valid).to be false
    end

    it "returns configuration_missing when API key is empty" do
      allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("")

      result = described_class.call(organization: organization)
      expect(result.status).to eq(:configuration_missing)
      expect(result.configuration_valid).to be false
    end

    it "returns quota_exceeded when quota is exhausted" do
      organization.update!(ai_monthly_token_limit: 100)
      conversation = Conversation.create!(organization: organization, user: user, title: "Test")
      AiUsageRecord.create!(
        organization: organization, user: user, conversation: conversation,
        provider: "openai", model: "gpt-5.6-luna", operation: "chat",
        prompt_tokens: 200, completion_tokens: 0, total_tokens: 200,
        estimated_cost: 0.01
      )

      result = described_class.call(organization: organization)
      expect(result.status).to eq(:quota_exceeded)
      expect(result.configuration_valid).to be true
    end

    it "returns operational when quota is not configured" do
      result = described_class.call(organization: organization)
      expect(result.status).to eq(:operational)
    end

    it "prioritizes configuration_missing over quota_exceeded" do
      allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return(nil)
      organization.update!(ai_monthly_token_limit: 0)

      result = described_class.call(organization: organization)
      expect(result.status).to eq(:configuration_missing)
    end

    it "returns a Result struct" do
      result = described_class.call(organization: organization)
      expect(result).to be_a(Ai::HealthCheck::Result)
      expect(result).to respond_to(:status)
      expect(result).to respond_to(:message)
      expect(result).to respond_to(:configuration_valid)
    end
  end
end
