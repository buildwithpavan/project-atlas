# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dashboard API", type: :request do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme") }
  let(:user) do
    User.create!(email: "user@example.com", first_name: "A", last_name: "B", password: "password123")
  end
  let!(:membership) { Membership.create!(user: user, organization: organization, role: "member") }
  let(:access_token) { Identity::AccessToken.encode(user) }
  let(:headers) { { "Authorization" => "Bearer #{access_token}" } }
  let(:upload) { Upload.create!(organization: organization, filename: "test.csv") }

  describe "GET /api/v1/dashboard" do
    describe "authentication" do
      it "rejects unauthenticated requests" do
        get "/api/v1/dashboard"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe "authorization" do
      it "rejects users with no organization membership" do
        orphan = User.create!(email: "orphan@example.com", first_name: "O", last_name: "P", password: "password123")
        token = Identity::AccessToken.encode(orphan)
        get "/api/v1/dashboard", headers: { "Authorization" => "Bearer #{token}" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe "empty state" do
      it "returns zeroed metrics when no tickets exist" do
        get "/api/v1/dashboard", headers: headers
        expect(response).to have_http_status(:ok)
        data = response.parsed_body["data"]
        expect(data["total_tickets"]).to eq(0)
        expect(data["analyzed_tickets"]).to eq(0)
        expect(data["sentiment_distribution"]).to eq({})
        expect(data["top_categories"]).to eq({})
        expect(data["feature_requests"]).to eq(0)
        expect(data["bug_reports"]).to eq(0)
      end
    end

    describe "with data" do
      before do
        t1 = Ticket.create!(organization: organization, upload: upload, subject: "T1")
        t2 = Ticket.create!(organization: organization, upload: upload, subject: "T2")
        t3 = Ticket.create!(organization: organization, upload: upload, subject: "T3")
        Ticket.create!(organization: organization, upload: upload, subject: "T4 unanalyzed")

        AiAnalysis.create!(
          organization: organization, ticket: t1, status: "completed",
          sentiment: "negative", category: "billing", confidence: 0.9,
          feature_request: true, bug_report: false, knowledge_gap: false,
          processed_at: Time.current
        )
        AiAnalysis.create!(
          organization: organization, ticket: t2, status: "completed",
          sentiment: "negative", category: "billing", confidence: 0.85,
          feature_request: false, bug_report: true, knowledge_gap: true,
          processed_at: Time.current
        )
        AiAnalysis.create!(
          organization: organization, ticket: t3, status: "completed",
          sentiment: "positive", category: "general", confidence: 0.95,
          feature_request: false, bug_report: false, knowledge_gap: false,
          processed_at: Time.current
        )
      end

      it "returns correct total_tickets" do
        get "/api/v1/dashboard", headers: headers
        expect(response.parsed_body["data"]["total_tickets"]).to eq(4)
      end

      it "returns correct analyzed_tickets count" do
        get "/api/v1/dashboard", headers: headers
        expect(response.parsed_body["data"]["analyzed_tickets"]).to eq(3)
      end

      it "returns sentiment_distribution" do
        get "/api/v1/dashboard", headers: headers
        dist = response.parsed_body["data"]["sentiment_distribution"]
        expect(dist["negative"]).to eq(2)
        expect(dist["positive"]).to eq(1)
      end

      it "returns top_categories" do
        get "/api/v1/dashboard", headers: headers
        cats = response.parsed_body["data"]["top_categories"]
        expect(cats["billing"]).to eq(2)
        expect(cats["general"]).to eq(1)
      end

      it "returns feature_requests count" do
        get "/api/v1/dashboard", headers: headers
        expect(response.parsed_body["data"]["feature_requests"]).to eq(1)
      end

      it "returns bug_reports count" do
        get "/api/v1/dashboard", headers: headers
        expect(response.parsed_body["data"]["bug_reports"]).to eq(1)
      end
    end

    describe "tenant isolation" do
      let(:other_org) { Organization.create!(name: "Other", slug: "other") }
      let(:other_upload) { Upload.create!(organization: other_org, filename: "other.csv") }

      before do
        Ticket.create!(organization: organization, upload: upload, subject: "Ours")

        other_ticket = Ticket.create!(organization: other_org, upload: other_upload, subject: "Theirs")
        AiAnalysis.create!(
          organization: other_org, ticket: other_ticket, status: "completed",
          sentiment: "positive", category: "general", confidence: 0.8,
          feature_request: true, bug_report: true, knowledge_gap: true,
          processed_at: Time.current
        )
      end

      it "excludes data from other organizations" do
        get "/api/v1/dashboard", headers: headers
        data = response.parsed_body["data"]
        expect(data["total_tickets"]).to eq(1)
        expect(data["analyzed_tickets"]).to eq(0)
        expect(data["feature_requests"]).to eq(0)
        expect(data["bug_reports"]).to eq(0)
      end
    end

    describe "excludes non-completed analyses" do
      before do
        t1 = Ticket.create!(organization: organization, upload: upload, subject: "T1")
        t2 = Ticket.create!(organization: organization, upload: upload, subject: "T2")

        AiAnalysis.create!(
          organization: organization, ticket: t1, status: "completed",
          sentiment: "neutral", category: "general", confidence: 0.8,
          feature_request: false, bug_report: false, knowledge_gap: false,
          processed_at: Time.current
        )
        AiAnalysis.create!(
          organization: organization, ticket: t2, status: "pending"
        )
      end

      it "only counts completed analyses" do
        get "/api/v1/dashboard", headers: headers
        data = response.parsed_body["data"]
        expect(data["analyzed_tickets"]).to eq(1)
        expect(data["sentiment_distribution"]).to eq({ "neutral" => 1 })
      end
    end

    describe "response shape" do
      it "returns expected top-level keys" do
        get "/api/v1/dashboard", headers: headers
        data = response.parsed_body["data"]
        expect(data.keys).to contain_exactly(
          "total_tickets", "analyzed_tickets", "sentiment_distribution",
          "top_categories", "feature_requests", "bug_reports"
        )
      end
    end
  end
end
