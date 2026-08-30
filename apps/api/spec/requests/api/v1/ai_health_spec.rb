# frozen_string_literal: true

require "rails_helper"

RSpec.describe "AI Health API", type: :request do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme") }
  let(:user) do
    User.create!(email: "user@example.com", first_name: "A", last_name: "B", password: "password123")
  end
  let!(:membership) { Membership.create!(user: user, organization: organization, role: "member") }
  let(:token) { Identity::AccessToken.encode(user) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("sk-test-key")
  end

  describe "GET /api/v1/ai/health" do
    it "rejects unauthenticated requests" do
      get "/api/v1/ai/health"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns operational status with configuration_valid" do
      get "/api/v1/ai/health", headers: headers
      expect(response).to have_http_status(:ok)
      data = response.parsed_body["data"]
      expect(data["status"]).to eq("operational")
      expect(data["message"]).to be_present
      expect(data["configuration_valid"]).to be true
      expect(data["checked_at"]).to be_present
    end

    it "returns configuration_missing when API key is not set" do
      allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return(nil)

      get "/api/v1/ai/health", headers: headers
      data = response.parsed_body["data"]
      expect(data["status"]).to eq("configuration_missing")
      expect(data["configuration_valid"]).to be false
    end

    it "returns quota_exceeded when quota is hit" do
      organization.update!(ai_monthly_token_limit: 0)
      conversation = Conversation.create!(organization: organization, user: user, title: "Test")
      AiUsageRecord.create!(
        organization: organization, user: user, conversation: conversation,
        provider: "openai", model: "gpt-5.6-luna", operation: "chat",
        prompt_tokens: 1, completion_tokens: 0, total_tokens: 1,
        estimated_cost: 0.0
      )

      get "/api/v1/ai/health", headers: headers
      expect(response).to have_http_status(:ok)
      data = response.parsed_body["data"]
      expect(data["status"]).to eq("quota_exceeded")
      expect(data["configuration_valid"]).to be true
    end

    it "does not expose internal details" do
      get "/api/v1/ai/health", headers: headers
      body = response.body
      expect(body).not_to include("api_key")
      expect(body).not_to include("secret")
    end
  end
end
