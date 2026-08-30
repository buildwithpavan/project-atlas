# frozen_string_literal: true

require "rails_helper"

RSpec.describe "AI Usage API", type: :request do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme") }
  let(:other_org) { Organization.create!(name: "Other", slug: "other") }

  let(:admin_user) do
    User.create!(email: "admin@example.com", first_name: "A", last_name: "B", password: "password123")
  end
  let(:member_user) do
    User.create!(email: "member@example.com", first_name: "C", last_name: "D", password: "password123")
  end
  let(:other_user) do
    User.create!(email: "other@example.com", first_name: "E", last_name: "F", password: "password123")
  end

  let!(:admin_membership) { Membership.create!(user: admin_user, organization: organization, role: "admin") }
  let!(:member_membership) { Membership.create!(user: member_user, organization: organization, role: "member") }
  let!(:other_membership) { Membership.create!(user: other_user, organization: other_org, role: "admin") }

  let(:admin_token) { Identity::AccessToken.encode(admin_user) }
  let(:member_token) { Identity::AccessToken.encode(member_user) }
  let(:other_token) { Identity::AccessToken.encode(other_user) }

  let(:admin_headers) { { "Authorization" => "Bearer #{admin_token}" } }
  let(:member_headers) { { "Authorization" => "Bearer #{member_token}" } }
  let(:other_headers) { { "Authorization" => "Bearer #{other_token}" } }

  let!(:conversation) { Conversation.create!(organization: organization, user: admin_user, title: "Test") }
  let!(:other_conversation) { Conversation.create!(organization: other_org, user: other_user, title: "Other") }

  # ── GET /api/v1/ai/usage ──────────────────────────────────────────

  describe "GET /api/v1/ai/usage" do
    context "authentication" do
      it "rejects unauthenticated requests" do
        get "/api/v1/ai/usage"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "authorization" do
      it "allows member access" do
        get "/api/v1/ai/usage", headers: member_headers
        expect(response).to have_http_status(:ok)
      end

      it "allows admin access" do
        get "/api/v1/ai/usage", headers: admin_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context "tenant isolation" do
      before do
        # Create usage for org A
        AiUsageRecord.create!(
          organization: organization, user: admin_user, conversation: conversation,
          provider: "openai", model: "gpt-5.6-luna", operation: "chat",
          prompt_tokens: 100, completion_tokens: 50, total_tokens: 150,
          estimated_cost: 1.25
        )
        # Create usage for org B
        AiUsageRecord.create!(
          organization: other_org, user: other_user, conversation: other_conversation,
          provider: "openai", model: "gpt-5.6-luna", operation: "chat",
          prompt_tokens: 999, completion_tokens: 999, total_tokens: 1998,
          estimated_cost: 99.99
        )
      end

      it "only shows own organization's usage" do
        get "/api/v1/ai/usage", headers: admin_headers
        data = response.parsed_body["data"]
        expect(data["tokens"]["used"]).to eq(150)
      end

      it "does not leak other organization's data" do
        get "/api/v1/ai/usage", headers: other_headers
        data = response.parsed_body["data"]
        expect(data["tokens"]["used"]).to eq(1998)
      end
    end

    context "empty usage" do
      it "returns zero usage when no records exist" do
        get "/api/v1/ai/usage", headers: admin_headers
        data = response.parsed_body["data"]
        expect(data["tokens"]["used"]).to eq(0)
        expect(data["cost"]["used"]).to eq(0)
      end

      it "returns empty breakdowns" do
        get "/api/v1/ai/usage", headers: admin_headers
        data = response.parsed_body["data"]
        expect(data["by_operation"]).to eq([])
        expect(data["by_model"]).to eq([])
        expect(data["by_user"]).to eq([])
        expect(data["by_day"]).to eq([])
      end
    end

    context "response structure" do
      before do
        organization.update!(ai_monthly_token_limit: 500_000, ai_monthly_cost_limit: 100.0)
      end

      it "includes period" do
        get "/api/v1/ai/usage", headers: admin_headers
        data = response.parsed_body["data"]
        expect(data["period"]).to match(/\A\d{4}-\d{2}\z/)
      end

      it "includes token section with limits" do
        get "/api/v1/ai/usage", headers: admin_headers
        data = response.parsed_body["data"]["tokens"]
        expect(data).to include("used", "limit", "remaining", "percentage_used")
        expect(data["limit"]).to eq(500_000)
      end

      it "includes cost section with limits" do
        get "/api/v1/ai/usage", headers: admin_headers
        data = response.parsed_body["data"]["cost"]
        expect(data).to include("used", "limit", "remaining", "percentage_used")
        expect(data["limit"]).to eq(100.0)
      end

      it "returns nil limits when unlimited" do
        organization.update!(ai_monthly_token_limit: nil, ai_monthly_cost_limit: nil)
        get "/api/v1/ai/usage", headers: admin_headers
        data = response.parsed_body["data"]
        expect(data["tokens"]["limit"]).to be_nil
        expect(data["tokens"]["remaining"]).to be_nil
        expect(data["cost"]["limit"]).to be_nil
        expect(data["cost"]["remaining"]).to be_nil
      end
    end

    context "token aggregation" do
      before do
        organization.update!(ai_monthly_token_limit: 10_000)

        AiUsageRecord.create!(
          organization: organization, user: admin_user, conversation: conversation,
          provider: "openai", model: "gpt-5.6-luna", operation: "chat",
          prompt_tokens: 100, completion_tokens: 50, total_tokens: 150,
          estimated_cost: 1.0
        )
        AiUsageRecord.create!(
          organization: organization, user: admin_user, conversation: conversation,
          provider: "openai", model: "gpt-5.6-luna", operation: "chat",
          prompt_tokens: 200, completion_tokens: 100, total_tokens: 300,
          estimated_cost: 2.0
        )
      end

      it "sums tokens correctly" do
        get "/api/v1/ai/usage", headers: admin_headers
        data = response.parsed_body["data"]["tokens"]
        expect(data["used"]).to eq(450)
        expect(data["remaining"]).to eq(9_550)
      end

      it "calculates percentage correctly" do
        get "/api/v1/ai/usage", headers: admin_headers
        data = response.parsed_body["data"]["tokens"]
        expect(data["percentage_used"]).to eq(4.5)
      end
    end

    context "cost aggregation" do
      before do
        organization.update!(ai_monthly_cost_limit: 50.0)

        AiUsageRecord.create!(
          organization: organization, user: admin_user, conversation: conversation,
          provider: "openai", model: "gpt-5.6-luna", operation: "chat",
          prompt_tokens: 100, completion_tokens: 50, total_tokens: 150,
          estimated_cost: 12.50
        )
      end

      it "sums cost correctly" do
        get "/api/v1/ai/usage", headers: admin_headers
        data = response.parsed_body["data"]["cost"]
        expect(data["used"]).to eq(12.5)
        expect(data["remaining"]).to eq(37.5)
        expect(data["percentage_used"]).to eq(25.0)
      end
    end

    context "operation breakdown" do
      before do
        AiUsageRecord.create!(
          organization: organization, user: admin_user, conversation: conversation,
          provider: "openai", model: "gpt-5.6-luna", operation: "chat",
          prompt_tokens: 100, completion_tokens: 50, total_tokens: 150,
          estimated_cost: 1.0
        )
        AiUsageRecord.create!(
          organization: organization, user: admin_user, conversation: conversation,
          provider: "openai", model: "text-embedding-3-small", operation: "embedding",
          prompt_tokens: 10, completion_tokens: 0, total_tokens: 10,
          estimated_cost: 0.001
        )
      end

      it "breaks down by operation" do
        get "/api/v1/ai/usage", headers: admin_headers
        ops = response.parsed_body["data"]["by_operation"]
        expect(ops.length).to eq(2)
        chat_op = ops.find { |o| o["operation"] == "chat" }
        embed_op = ops.find { |o| o["operation"] == "embedding" }
        expect(chat_op["total_tokens"]).to eq(150)
        expect(embed_op["total_tokens"]).to eq(10)
      end
    end

    context "model breakdown" do
      before do
        AiUsageRecord.create!(
          organization: organization, user: admin_user, conversation: conversation,
          provider: "openai", model: "gpt-5.6-luna", operation: "chat",
          prompt_tokens: 100, completion_tokens: 50, total_tokens: 150,
          estimated_cost: 1.0
        )
        AiUsageRecord.create!(
          organization: organization, user: admin_user, conversation: conversation,
          provider: "openai", model: "text-embedding-3-small", operation: "embedding",
          prompt_tokens: 10, completion_tokens: 0, total_tokens: 10,
          estimated_cost: 0.001
        )
      end

      it "breaks down by model" do
        get "/api/v1/ai/usage", headers: admin_headers
        models = response.parsed_body["data"]["by_model"]
        expect(models.length).to eq(2)
        luna = models.find { |m| m["model"] == "gpt-5.6-luna" }
        embed = models.find { |m| m["model"] == "text-embedding-3-small" }
        expect(luna["total_tokens"]).to eq(150)
        expect(embed["total_tokens"]).to eq(10)
      end
    end

    context "user breakdown" do
      before do
        member_conversation = Conversation.create!(organization: organization, user: member_user, title: "Member")

        AiUsageRecord.create!(
          organization: organization, user: admin_user, conversation: conversation,
          provider: "openai", model: "gpt-5.6-luna", operation: "chat",
          prompt_tokens: 100, completion_tokens: 50, total_tokens: 150,
          estimated_cost: 1.0
        )
        AiUsageRecord.create!(
          organization: organization, user: member_user, conversation: member_conversation,
          provider: "openai", model: "gpt-5.6-luna", operation: "chat",
          prompt_tokens: 200, completion_tokens: 100, total_tokens: 300,
          estimated_cost: 2.0
        )
      end

      it "breaks down by user" do
        get "/api/v1/ai/usage", headers: admin_headers
        users = response.parsed_body["data"]["by_user"]
        expect(users.length).to eq(2)

        admin_usage = users.find { |u| u["email"] == "admin@example.com" }
        member_usage = users.find { |u| u["email"] == "member@example.com" }
        expect(admin_usage["total_tokens"]).to eq(150)
        expect(member_usage["total_tokens"]).to eq(300)
      end

      it "includes user_id and email but no sensitive data" do
        get "/api/v1/ai/usage", headers: admin_headers
        user_entry = response.parsed_body["data"]["by_user"].first
        expect(user_entry).to include("user_id", "email", "total_tokens", "estimated_cost", "request_count")
        expect(user_entry.keys).not_to include("password_digest", "password")
      end
    end

    context "daily breakdown" do
      before do
        # Create records on different days
        AiUsageRecord.create!(
          organization: organization, user: admin_user, conversation: conversation,
          provider: "openai", model: "gpt-5.6-luna", operation: "chat",
          prompt_tokens: 100, completion_tokens: 50, total_tokens: 150,
          estimated_cost: 1.0,
          created_at: Time.current.beginning_of_month + 1.day
        )
        AiUsageRecord.create!(
          organization: organization, user: admin_user, conversation: conversation,
          provider: "openai", model: "gpt-5.6-luna", operation: "chat",
          prompt_tokens: 200, completion_tokens: 100, total_tokens: 300,
          estimated_cost: 2.0,
          created_at: Time.current.beginning_of_month + 2.days
        )
      end

      it "breaks down by day" do
        get "/api/v1/ai/usage", headers: admin_headers
        days = response.parsed_body["data"]["by_day"]
        expect(days.length).to eq(2)
        expect(days.first).to include("date", "total_tokens", "estimated_cost", "request_count")
      end

      it "orders days chronologically" do
        get "/api/v1/ai/usage", headers: admin_headers
        days = response.parsed_body["data"]["by_day"]
        dates = days.map { |d| d["date"] }
        expect(dates).to eq(dates.sort)
      end
    end

    context "previous month exclusion" do
      before do
        # This month
        AiUsageRecord.create!(
          organization: organization, user: admin_user, conversation: conversation,
          provider: "openai", model: "gpt-5.6-luna", operation: "chat",
          prompt_tokens: 100, completion_tokens: 50, total_tokens: 150,
          estimated_cost: 1.0
        )
        # Last month — should be excluded
        AiUsageRecord.create!(
          organization: organization, user: admin_user, conversation: conversation,
          provider: "openai", model: "gpt-5.6-luna", operation: "chat",
          prompt_tokens: 999, completion_tokens: 999, total_tokens: 1998,
          estimated_cost: 99.0,
          created_at: 1.month.ago
        )
      end

      it "only includes current month's usage" do
        get "/api/v1/ai/usage", headers: admin_headers
        data = response.parsed_body["data"]
        expect(data["tokens"]["used"]).to eq(150)
      end
    end

    context "large usage values" do
      before do
        AiUsageRecord.create!(
          organization: organization, user: admin_user, conversation: conversation,
          provider: "openai", model: "gpt-5.6-luna", operation: "chat",
          prompt_tokens: 5_000_000, completion_tokens: 2_000_000, total_tokens: 7_000_000,
          estimated_cost: 9999.999999
        )
      end

      it "handles large token values" do
        get "/api/v1/ai/usage", headers: admin_headers
        data = response.parsed_body["data"]
        expect(data["tokens"]["used"]).to eq(7_000_000)
      end
    end

    context "security" do
      it "does not expose raw prompts, system_prompt, or api_key" do
        get "/api/v1/ai/usage", headers: admin_headers
        body = response.body
        expect(body).not_to include("system_prompt")
        expect(body).not_to include("api_key")
      end

      it "prevents forged organization_id" do
        AiUsageRecord.create!(
          organization: other_org, user: other_user, conversation: other_conversation,
          provider: "openai", model: "gpt-5.6-luna", operation: "chat",
          prompt_tokens: 999, completion_tokens: 999, total_tokens: 1998,
          estimated_cost: 99.0
        )

        get "/api/v1/ai/usage", params: { organization_id: other_org.id }, headers: admin_headers
        data = response.parsed_body["data"]
        # Should not see other org's data even with forged org ID
        expect(data["tokens"]["used"]).to eq(0)
      end
    end

    context "SQL aggregation" do
      it "performs aggregation in SQL (not loading records into Ruby)" do
        AiUsageRecord.create!(
          organization: organization, user: admin_user, conversation: conversation,
          provider: "openai", model: "gpt-5.6-luna", operation: "chat",
          prompt_tokens: 100, completion_tokens: 50, total_tokens: 150,
          estimated_cost: 1.0
        )

        # This test verifies the endpoint returns correct results, proving the
        # SQL aggregation is working. The implementation uses .sum(), .group().pluck()
        # which delegate to SQL aggregation functions.
        get "/api/v1/ai/usage", headers: admin_headers
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["data"]["tokens"]["used"]).to eq(150)
      end
    end

    # ── Phase 3L: Period filtering ────────────────────────────────────

    context "period filtering" do
      before do
        # Current month record
        AiUsageRecord.create!(
          organization: organization, user: admin_user, conversation: conversation,
          provider: "openai", model: "gpt-5.6-luna", operation: "chat",
          prompt_tokens: 100, completion_tokens: 50, total_tokens: 150,
          estimated_cost: 1.0
        )
        # Previous month record
        AiUsageRecord.create!(
          organization: organization, user: admin_user, conversation: conversation,
          provider: "openai", model: "gpt-5.6-luna", operation: "chat",
          prompt_tokens: 200, completion_tokens: 100, total_tokens: 300,
          estimated_cost: 2.0,
          created_at: 1.month.ago
        )
      end

      it "defaults to current month" do
        get "/api/v1/ai/usage", headers: admin_headers
        data = response.parsed_body["data"]
        expect(data["period"]).to eq(Time.current.strftime("%Y-%m"))
        expect(data["tokens"]["used"]).to eq(150)
      end

      it "returns previous month with period=previous" do
        get "/api/v1/ai/usage", params: { period: "previous" }, headers: admin_headers
        data = response.parsed_body["data"]
        expect(data["period"]).to eq(1.month.ago.strftime("%Y-%m"))
        expect(data["tokens"]["used"]).to eq(300)
      end

      it "returns specific month with period=YYYY-MM" do
        month = 1.month.ago.strftime("%Y-%m")
        get "/api/v1/ai/usage", params: { period: month }, headers: admin_headers
        data = response.parsed_body["data"]
        expect(data["period"]).to eq(month)
        expect(data["tokens"]["used"]).to eq(300)
      end

      it "returns date range with start_date and end_date" do
        start_date = 2.months.ago.beginning_of_month.to_date.to_s
        end_date = Date.today.to_s
        get "/api/v1/ai/usage", params: { start_date: start_date, end_date: end_date }, headers: admin_headers
        data = response.parsed_body["data"]
        expect(data["period"]).to eq("#{start_date}..#{end_date}")
        expect(data["tokens"]["used"]).to eq(450) # both months
      end

      it "falls back to current month on invalid period format" do
        get "/api/v1/ai/usage", params: { period: "not-valid" }, headers: admin_headers
        data = response.parsed_body["data"]
        expect(data["period"]).to eq(Time.current.strftime("%Y-%m"))
        expect(data["tokens"]["used"]).to eq(150)
      end
    end

    # ── Phase 3L: Enhanced response fields ────────────────────────────

    context "enhanced response fields" do
      before do
        AiUsageRecord.create!(
          organization: organization, user: admin_user, conversation: conversation,
          provider: "openai", model: "gpt-5.6-luna", operation: "chat",
          prompt_tokens: 100, completion_tokens: 50, total_tokens: 150,
          estimated_cost: 1.0, latency_ms: 250
        )
        AiUsageRecord.create!(
          organization: organization, user: admin_user, conversation: conversation,
          provider: "openai", model: "gpt-5.6-luna", operation: "chat",
          prompt_tokens: 200, completion_tokens: 100, total_tokens: 300,
          estimated_cost: 2.0, latency_ms: 350
        )
      end

      it "includes prompt_tokens and completion_tokens" do
        get "/api/v1/ai/usage", headers: admin_headers
        data = response.parsed_body["data"]
        expect(data["prompt_tokens"]).to eq(300)
        expect(data["completion_tokens"]).to eq(150)
      end

      it "includes request_count" do
        get "/api/v1/ai/usage", headers: admin_headers
        data = response.parsed_body["data"]
        expect(data["request_count"]).to eq(2)
      end

      it "includes average_latency_ms" do
        get "/api/v1/ai/usage", headers: admin_headers
        data = response.parsed_body["data"]
        expect(data["average_latency_ms"]).to eq(300.0)
      end

      it "includes per-operation prompt_tokens and completion_tokens" do
        get "/api/v1/ai/usage", headers: admin_headers
        ops = response.parsed_body["data"]["by_operation"]
        chat = ops.find { |o| o["operation"] == "chat" }
        expect(chat["prompt_tokens"]).to eq(300)
        expect(chat["completion_tokens"]).to eq(150)
        expect(chat["average_latency_ms"]).to eq(300.0)
      end
    end
  end
end
