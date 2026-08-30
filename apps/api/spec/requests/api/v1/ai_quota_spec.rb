# frozen_string_literal: true

require "rails_helper"

RSpec.describe "AI Quota API", type: :request do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme") }
  let(:other_org) { Organization.create!(name: "Other", slug: "other") }

  let(:admin_user) do
    User.create!(email: "admin@example.com", first_name: "A", last_name: "B", password: "password123")
  end
  let(:member_user) do
    User.create!(email: "member@example.com", first_name: "C", last_name: "D", password: "password123")
  end
  let(:viewer_user) do
    User.create!(email: "viewer@example.com", first_name: "E", last_name: "F", password: "password123")
  end
  let(:other_admin) do
    User.create!(email: "other_admin@example.com", first_name: "G", last_name: "H", password: "password123")
  end

  let!(:admin_membership) { Membership.create!(user: admin_user, organization: organization, role: "admin") }
  let!(:member_membership) { Membership.create!(user: member_user, organization: organization, role: "member") }
  let!(:viewer_membership) { Membership.create!(user: viewer_user, organization: organization, role: "viewer") }
  let!(:other_membership) { Membership.create!(user: other_admin, organization: other_org, role: "admin") }

  let(:admin_token) { Identity::AccessToken.encode(admin_user) }
  let(:member_token) { Identity::AccessToken.encode(member_user) }
  let(:viewer_token) { Identity::AccessToken.encode(viewer_user) }
  let(:other_admin_token) { Identity::AccessToken.encode(other_admin) }

  let(:admin_headers) { { "Authorization" => "Bearer #{admin_token}" } }
  let(:member_headers) { { "Authorization" => "Bearer #{member_token}" } }
  let(:viewer_headers) { { "Authorization" => "Bearer #{viewer_token}" } }
  let(:other_admin_headers) { { "Authorization" => "Bearer #{other_admin_token}" } }

  # ── GET /api/v1/ai/quota ──────────────────────────────────────────

  describe "GET /api/v1/ai/quota" do
    context "authentication" do
      it "rejects unauthenticated requests" do
        get "/api/v1/ai/quota"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "authorization" do
      it "allows viewer access" do
        get "/api/v1/ai/quota", headers: viewer_headers
        expect(response).to have_http_status(:ok)
      end

      it "allows member access" do
        get "/api/v1/ai/quota", headers: member_headers
        expect(response).to have_http_status(:ok)
      end

      it "allows admin access" do
        get "/api/v1/ai/quota", headers: admin_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context "tenant isolation" do
      before do
        organization.update!(ai_monthly_token_limit: 100_000)
        other_org.update!(ai_monthly_token_limit: 999_999)
      end

      it "returns the correct organization's quota" do
        get "/api/v1/ai/quota", headers: admin_headers
        data = response.parsed_body["data"]
        expect(data["ai_monthly_token_limit"]).to eq(100_000)
      end

      it "does not expose other organization's quota" do
        get "/api/v1/ai/quota", headers: other_admin_headers
        data = response.parsed_body["data"]
        expect(data["ai_monthly_token_limit"]).to eq(999_999)
      end
    end

    context "response structure" do
      before { organization.update!(ai_monthly_token_limit: 500_000, ai_monthly_cost_limit: 100.0) }

      it "returns complete quota data" do
        get "/api/v1/ai/quota", headers: admin_headers
        data = response.parsed_body["data"]

        expect(data).to include(
          "ai_monthly_token_limit" => 500_000,
          "ai_monthly_cost_limit" => 100.0
        )
        expect(data).to have_key("ai_quota_reserved_tokens")
        expect(data).to have_key("period")
        expect(data["period"]).to match(/\A\d{4}-\d{2}\z/)
        expect(data["current_month"]).to include(
          "tokens_used", "cost_used",
          "tokens_remaining", "cost_remaining",
          "token_percentage_used", "cost_percentage_used"
        )
      end

      it "shows usage against quota" do
        conversation = Conversation.create!(organization: organization, user: admin_user, title: "Test")
        AiUsageRecord.create!(
          organization: organization, user: admin_user, conversation: conversation,
          provider: "openai", model: "gpt-5.6-luna", operation: "chat",
          prompt_tokens: 100, completion_tokens: 50, total_tokens: 150,
          estimated_cost: 1.50
        )

        get "/api/v1/ai/quota", headers: admin_headers
        data = response.parsed_body["data"]["current_month"]

        expect(data["tokens_used"]).to eq(150)
        expect(data["tokens_remaining"]).to eq(499_850)
        expect(data["cost_used"]).to eq(1.5)
        expect(data["cost_remaining"]).to eq(98.5)
      end

      it "returns nil remaining when limits are unlimited" do
        organization.update!(ai_monthly_token_limit: nil, ai_monthly_cost_limit: nil)
        get "/api/v1/ai/quota", headers: admin_headers
        data = response.parsed_body["data"]["current_month"]

        expect(data["tokens_remaining"]).to be_nil
        expect(data["cost_remaining"]).to be_nil
        expect(data["token_percentage_used"]).to be_nil
        expect(data["cost_percentage_used"]).to be_nil
      end
    end
  end

  # ── PATCH /api/v1/ai/quota ────────────────────────────────────────

  describe "PATCH /api/v1/ai/quota" do
    context "authentication" do
      it "rejects unauthenticated requests" do
        patch "/api/v1/ai/quota", params: { quota: { ai_monthly_token_limit: 100 } }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "authorization" do
      it "rejects viewer" do
        patch "/api/v1/ai/quota", params: { quota: { ai_monthly_token_limit: 100 } }, headers: viewer_headers
        expect(response).to have_http_status(:forbidden)
      end

      it "rejects member" do
        patch "/api/v1/ai/quota", params: { quota: { ai_monthly_token_limit: 100 } }, headers: member_headers
        expect(response).to have_http_status(:forbidden)
      end

      it "allows admin" do
        patch "/api/v1/ai/quota", params: { quota: { ai_monthly_token_limit: 100 } }, headers: admin_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context "tenant isolation / IDOR" do
      it "updates the correct organization" do
        patch "/api/v1/ai/quota",
              params: { quota: { ai_monthly_token_limit: 250_000 } },
              headers: admin_headers
        expect(organization.reload.ai_monthly_token_limit).to eq(250_000)
        expect(other_org.reload.ai_monthly_token_limit).to be_nil
      end

      it "cannot update another organization's quota" do
        patch "/api/v1/ai/quota",
              params: { quota: { ai_monthly_token_limit: 250_000 } },
              headers: other_admin_headers
        expect(organization.reload.ai_monthly_token_limit).to be_nil
      end

      it "ignores forged organization_id in params" do
        patch "/api/v1/ai/quota",
              params: { quota: { ai_monthly_token_limit: 250_000 }, organization_id: other_org.id },
              headers: admin_headers
        # Should update admin's own org, not the forged org
        expect(organization.reload.ai_monthly_token_limit).to eq(250_000)
        expect(other_org.reload.ai_monthly_token_limit).to be_nil
      end
    end

    context "valid quota values" do
      it "sets token limit" do
        patch "/api/v1/ai/quota",
              params: { quota: { ai_monthly_token_limit: 500_000 } },
              headers: admin_headers
        expect(response).to have_http_status(:ok)
        expect(organization.reload.ai_monthly_token_limit).to eq(500_000)
      end

      it "sets cost limit" do
        patch "/api/v1/ai/quota",
              params: { quota: { ai_monthly_cost_limit: 99.99 } },
              headers: admin_headers
        expect(response).to have_http_status(:ok)
        expect(organization.reload.ai_monthly_cost_limit).to eq(99.99)
      end

      it "sets nil (unlimited) token limit" do
        organization.update!(ai_monthly_token_limit: 1000)
        patch "/api/v1/ai/quota",
              params: { quota: { ai_monthly_token_limit: nil } },
              headers: admin_headers
        expect(response).to have_http_status(:ok)
        expect(organization.reload.ai_monthly_token_limit).to be_nil
      end

      it "sets nil (unlimited) cost limit" do
        organization.update!(ai_monthly_cost_limit: 50.0)
        patch "/api/v1/ai/quota",
              params: { quota: { ai_monthly_cost_limit: nil } },
              headers: admin_headers
        expect(response).to have_http_status(:ok)
        expect(organization.reload.ai_monthly_cost_limit).to be_nil
      end

      it "sets zero token limit" do
        patch "/api/v1/ai/quota",
              params: { quota: { ai_monthly_token_limit: 0 } },
              headers: admin_headers
        expect(response).to have_http_status(:ok)
        expect(organization.reload.ai_monthly_token_limit).to eq(0)
      end

      it "sets zero cost limit" do
        patch "/api/v1/ai/quota",
              params: { quota: { ai_monthly_cost_limit: 0 } },
              headers: admin_headers
        expect(response).to have_http_status(:ok)
        expect(organization.reload.ai_monthly_cost_limit).to eq(0)
      end
    end

    context "invalid quota values" do
      it "rejects negative token limit" do
        patch "/api/v1/ai/quota",
              params: { quota: { ai_monthly_token_limit: -100 } },
              headers: admin_headers
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "rejects negative cost limit" do
        patch "/api/v1/ai/quota",
              params: { quota: { ai_monthly_cost_limit: -50.0 } },
              headers: admin_headers
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "rejects non-numeric token limit" do
        patch "/api/v1/ai/quota",
              params: { quota: { ai_monthly_token_limit: "abc" } },
              headers: admin_headers
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "rejects non-numeric cost limit" do
        patch "/api/v1/ai/quota",
              params: { quota: { ai_monthly_cost_limit: "xyz" } },
              headers: admin_headers
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "mass assignment protection" do
      it "does not allow setting arbitrary organization fields" do
        original_name = organization.name
        patch "/api/v1/ai/quota",
              params: { quota: { ai_monthly_token_limit: 100, name: "Hacked" } },
              headers: admin_headers
        expect(organization.reload.name).to eq(original_name)
      end
    end

    context "response format" do
      it "returns RFC 9457 error format for validation failures" do
        patch "/api/v1/ai/quota",
              params: { quota: { ai_monthly_token_limit: -1 } },
              headers: admin_headers
        body = response.parsed_body
        expect(body["type"]).to eq("/errors/validation")
        expect(body["status"]).to eq(422)
      end

      it "returns updated quota data on success" do
        patch "/api/v1/ai/quota",
              params: { quota: { ai_monthly_token_limit: 300_000 } },
              headers: admin_headers
        data = response.parsed_body["data"]
        expect(data["ai_monthly_token_limit"]).to eq(300_000)
      end
    end
  end
end
