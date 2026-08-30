# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Executive Summaries API", type: :request do
  let(:organization) { Organization.create!(name: "Acme Corp", slug: "acme") }
  let(:user) do
    User.create!(email: "user@example.com", first_name: "A", last_name: "B", password: "password123")
  end
  let!(:membership) { Membership.create!(user: user, organization: organization, role: "member") }
  let(:access_token) { Identity::AccessToken.encode(user) }
  let(:headers) { { "Authorization" => "Bearer #{access_token}" } }
  let(:upload) { Upload.create!(organization: organization, filename: "test.csv") }

  def create_completed_analysis(org, upload_record)
    ticket = Ticket.create!(organization: org, upload: upload_record, subject: "Help", description: "Need help")
    AiAnalysis.create!(
      organization: org, ticket: ticket, status: "completed",
      sentiment: "negative", category: "billing", confidence: 0.9,
      summary: "Customer needs billing help", feature_request: false,
      bug_report: false, knowledge_gap: false, processed_at: Time.current
    )
  end

  describe "POST /api/v1/reports/executive-summary" do
    describe "authentication" do
      it "rejects unauthenticated requests" do
        post "/api/v1/reports/executive-summary"
        expect(response).to have_http_status(:unauthorized)
      end

      it "rejects invalid token" do
        post "/api/v1/reports/executive-summary", headers: { "Authorization" => "Bearer invalid" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe "authorization" do
      it "rejects authenticated user without organization" do
        orphan = User.create!(email: "orphan@example.com", first_name: "O", last_name: "P", password: "password123")
        token = Identity::AccessToken.encode(orphan)
        post "/api/v1/reports/executive-summary", headers: { "Authorization" => "Bearer #{token}" }
        expect(response).to have_http_status(:unauthorized)
      end

      it "rejects members from generating executive summaries" do
        membership.update!(role: "member")
        post "/api/v1/reports/executive-summary", headers: headers
        expect(response).to have_http_status(:forbidden)
      end

      it "rejects viewers from generating executive summaries" do
        membership.update!(role: "viewer")
        post "/api/v1/reports/executive-summary", headers: headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "validation errors" do
      before { membership.update!(role: "admin") }

      it "returns RFC 9457 error when no analyses exist" do
        post "/api/v1/reports/executive-summary", headers: headers
        expect(response).to have_http_status(:unprocessable_content)

        body = response.parsed_body
        expect(body["type"]).to eq("/errors/validation")
        expect(body["title"]).to eq("Validation Error")
        expect(body["detail"]).to include("No analyzed conversations")
      end
    end

    describe "successful generation" do
      let(:mock_parsed) do
        instance_double(
          Ai::Schemas::ExecutiveSummaryOutput,
          summary: "Customer feedback centers on billing concerns.",
          key_findings: [
            instance_double(Ai::Schemas::KeyFinding,
              title: "Billing issues", description: "Top concern", evidence_count: 1, category: "billing")
          ],
          attention_items: [
            instance_double(Ai::Schemas::AttentionItem,
              title: "Urgent bugs", description: "Multiple bugs", priority: :high, evidence_count: 1)
          ],
          recommended_actions: [
            instance_double(Ai::Schemas::RecommendedAction,
              title: "Fix billing", description: "Review billing flow", evidence_count: 1)
          ]
        )
      end

      before do
        membership.update!(role: "admin")
        allow(Ai::Providers::Openai).to receive(:generate_executive_summary).and_return(mock_parsed)
        create_completed_analysis(organization, upload)
      end

      it "returns 201 with summary data" do
        post "/api/v1/reports/executive-summary", headers: headers
        expect(response).to have_http_status(:created)

        data = response.parsed_body["data"]
        expect(data["summary"]).to include("billing")
        expect(data["key_findings"]).to be_an(Array)
        expect(data["attention_items"]).to be_an(Array)
        expect(data["recommended_actions"]).to be_an(Array)
        expect(data["analyzed_ticket_count"]).to eq(1)
        expect(data["generated_at"]).to be_present
        expect(data["stale"]).to be(false)
        expect(data["id"]).to be_present
      end

      it "persists the executive summary" do
        expect { post "/api/v1/reports/executive-summary", headers: headers }
          .to change(ExecutiveSummary, :count).by(1)
      end
    end

    describe "AI provider errors" do
      before do
        membership.update!(role: "admin")
        create_completed_analysis(organization, upload)
        allow(Ai::Providers::Openai).to receive(:generate_executive_summary)
          .and_raise(KeyError, "OPENAI_API_KEY environment variable is not set")
      end

      it "returns service unavailable when API key is missing" do
        post "/api/v1/reports/executive-summary", headers: headers
        expect(response).to have_http_status(:service_unavailable)

        body = response.parsed_body
        expect(body["type"]).to eq("/errors/ai-unavailable")
      end
    end
  end

  describe "GET /api/v1/reports/executive-summary" do
    describe "authentication" do
      it "rejects unauthenticated requests" do
        get "/api/v1/reports/executive-summary"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe "authorization" do
      it "allows viewers to read executive summary" do
        membership.update!(role: "viewer")
        get "/api/v1/reports/executive-summary", headers: headers
        # 404 is fine here - it means auth passed, no summary exists yet
        expect(response).to have_http_status(:not_found)
      end
    end

    describe "when no summary exists" do
      it "returns not found" do
        get "/api/v1/reports/executive-summary", headers: headers
        expect(response).to have_http_status(:not_found)

        body = response.parsed_body
        expect(body["title"]).to include("Not Found")
      end
    end

    describe "when summary exists" do
      before do
        create_completed_analysis(organization, upload)
        ExecutiveSummary.create!(
          organization: organization,
          summary: "Executive overview of customer feedback.",
          key_findings: [ { "title" => "Billing", "description" => "Top issue", "evidence_count" => 5 } ],
          attention_items: [ { "title" => "Bugs", "description" => "Rising", "priority" => "high", "evidence_count" => 3 } ],
          recommended_actions: [ { "title" => "Review billing", "description" => "Improve flow", "evidence_count" => 5 } ],
          analyzed_ticket_count: 1,
          generated_at: Time.current
        )
      end

      it "returns the summary" do
        get "/api/v1/reports/executive-summary", headers: headers
        expect(response).to have_http_status(:ok)

        data = response.parsed_body["data"]
        expect(data["summary"]).to include("Executive overview")
        expect(data["key_findings"].size).to eq(1)
        expect(data["attention_items"].size).to eq(1)
        expect(data["recommended_actions"].size).to eq(1)
        expect(data["analyzed_ticket_count"]).to eq(1)
        expect(data["generated_at"]).to be_present
      end

      it "detects staleness when new analyses exist" do
        # Create another analysis that wasn't included in the summary
        create_completed_analysis(organization, upload)

        get "/api/v1/reports/executive-summary", headers: headers
        data = response.parsed_body["data"]

        expect(data["stale"]).to be(true)
      end

      it "reports not stale when counts match" do
        get "/api/v1/reports/executive-summary", headers: headers
        data = response.parsed_body["data"]

        expect(data["stale"]).to be(false)
      end
    end
  end
end
