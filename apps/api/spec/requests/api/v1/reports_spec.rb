# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reports API", type: :request do
  let(:organization) { Organization.create!(name: "Acme Corp", slug: "acme") }
  let(:user) do
    User.create!(email: "user@example.com", first_name: "A", last_name: "B", password: "password123")
  end
  let!(:membership) { Membership.create!(user: user, organization: organization, role: "member") }
  let(:access_token) { Identity::AccessToken.encode(user) }
  let(:headers) { { "Authorization" => "Bearer #{access_token}" } }
  let(:upload) { Upload.create!(organization: organization, filename: "test.csv") }

  describe "GET /api/v1/reports" do
    describe "authentication" do
      it "rejects unauthenticated requests" do
        get "/api/v1/reports"
        expect(response).to have_http_status(:unauthorized)
      end

      it "rejects invalid token" do
        get "/api/v1/reports", headers: { "Authorization" => "Bearer invalid" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe "authorization" do
      it "rejects authenticated user without organization" do
        orphan = User.create!(email: "orphan@example.com", first_name: "O", last_name: "P", password: "password123")
        token = Identity::AccessToken.encode(orphan)
        get "/api/v1/reports", headers: { "Authorization" => "Bearer #{token}" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe "empty organization" do
      it "returns a valid zero/empty report" do
        get "/api/v1/reports", headers: headers
        expect(response).to have_http_status(:ok)
        data = response.parsed_body["data"]

        expect(data["tickets"]["total"]).to eq(0)
        expect(data["tickets"]["analyzed"]).to eq(0)
        expect(data["tickets"]["unanalyzed"]).to eq(0)
        expect(data["sentiment"]["distribution"]).to eq({})
        expect(data["sentiment"]["percentages"]).to eq({})
        expect(data["categories"]["distribution"]).to eq({})
        expect(data["categories"]["top"]).to eq({})
        expect(data["classifications"]["feature_requests"]).to eq(0)
        expect(data["classifications"]["bug_reports"]).to eq(0)
        expect(data["classifications"]["knowledge_gaps"]).to eq(0)
        expect(data["status_distribution"]).to eq({})
        expect(data["priority_distribution"]).to eq({})
        expect(data["timeline"]).to eq({})
      end
    end

    context "with ticket and analysis data" do
      let!(:t1) do
        Ticket.create!(
          organization: organization, upload: upload, subject: "Login bug",
          status: "open", priority: "high", created_at: Time.new(2026, 7, 15)
        )
      end
      let!(:t2) do
        Ticket.create!(
          organization: organization, upload: upload, subject: "Billing question",
          status: "open", priority: "medium", created_at: Time.new(2026, 7, 20)
        )
      end
      let!(:t3) do
        Ticket.create!(
          organization: organization, upload: upload, subject: "Feature idea",
          status: "closed", priority: "low", created_at: Time.new(2026, 8, 1)
        )
      end
      let!(:t4) do
        Ticket.create!(
          organization: organization, upload: upload, subject: "Unanalyzed ticket",
          status: "open", priority: "high", created_at: Time.new(2026, 8, 5)
        )
      end

      let!(:a1) do
        AiAnalysis.create!(
          organization: organization, ticket: t1, status: "completed",
          sentiment: "negative", category: "account", confidence: 0.92,
          feature_request: false, bug_report: true, knowledge_gap: true,
          processed_at: Time.current
        )
      end
      let!(:a2) do
        AiAnalysis.create!(
          organization: organization, ticket: t2, status: "completed",
          sentiment: "neutral", category: "billing", confidence: 0.85,
          feature_request: false, bug_report: false, knowledge_gap: false,
          processed_at: Time.current
        )
      end
      let!(:a3) do
        AiAnalysis.create!(
          organization: organization, ticket: t3, status: "completed",
          sentiment: "positive", category: "billing", confidence: 0.95,
          feature_request: true, bug_report: false, knowledge_gap: false,
          processed_at: Time.current
        )
      end

      describe "ticket metrics" do
        it "returns correct total ticket count" do
          get "/api/v1/reports", headers: headers
          expect(response.parsed_body["data"]["tickets"]["total"]).to eq(4)
        end

        it "returns correct analyzed count" do
          get "/api/v1/reports", headers: headers
          expect(response.parsed_body["data"]["tickets"]["analyzed"]).to eq(3)
        end

        it "returns correct unanalyzed count" do
          get "/api/v1/reports", headers: headers
          expect(response.parsed_body["data"]["tickets"]["unanalyzed"]).to eq(1)
        end
      end

      describe "sentiment distribution" do
        it "returns sentiment counts" do
          get "/api/v1/reports", headers: headers
          dist = response.parsed_body["data"]["sentiment"]["distribution"]
          expect(dist["negative"]).to eq(1)
          expect(dist["neutral"]).to eq(1)
          expect(dist["positive"]).to eq(1)
        end

        it "returns sentiment percentages" do
          get "/api/v1/reports", headers: headers
          pcts = response.parsed_body["data"]["sentiment"]["percentages"]
          expect(pcts["negative"]).to eq(33.3)
          expect(pcts["neutral"]).to eq(33.3)
          expect(pcts["positive"]).to eq(33.3)
        end
      end

      describe "category distribution" do
        it "returns category counts ordered by frequency" do
          get "/api/v1/reports", headers: headers
          dist = response.parsed_body["data"]["categories"]["distribution"]
          expect(dist["billing"]).to eq(2)
          expect(dist["account"]).to eq(1)
        end

        it "returns top categories" do
          get "/api/v1/reports", headers: headers
          top = response.parsed_body["data"]["categories"]["top"]
          expect(top.keys.first).to eq("billing")
        end
      end

      describe "AI classifications" do
        it "returns feature request count" do
          get "/api/v1/reports", headers: headers
          expect(response.parsed_body["data"]["classifications"]["feature_requests"]).to eq(1)
        end

        it "returns bug report count" do
          get "/api/v1/reports", headers: headers
          expect(response.parsed_body["data"]["classifications"]["bug_reports"]).to eq(1)
        end

        it "returns knowledge gap count" do
          get "/api/v1/reports", headers: headers
          expect(response.parsed_body["data"]["classifications"]["knowledge_gaps"]).to eq(1)
        end
      end

      describe "ticket status distribution" do
        it "returns status counts" do
          get "/api/v1/reports", headers: headers
          dist = response.parsed_body["data"]["status_distribution"]
          expect(dist["open"]).to eq(3)
          expect(dist["closed"]).to eq(1)
        end
      end

      describe "ticket priority distribution" do
        it "returns priority counts" do
          get "/api/v1/reports", headers: headers
          dist = response.parsed_body["data"]["priority_distribution"]
          expect(dist["high"]).to eq(2)
          expect(dist["medium"]).to eq(1)
          expect(dist["low"]).to eq(1)
        end
      end

      describe "time-based breakdown" do
        it "returns monthly ticket counts" do
          get "/api/v1/reports", headers: headers
          timeline = response.parsed_body["data"]["timeline"]
          expect(timeline["2026-07"]).to eq(2)
          expect(timeline["2026-08"]).to eq(2)
        end
      end

      describe "metadata" do
        it "includes generated_at timestamp" do
          freeze_time do
            get "/api/v1/reports", headers: headers
            expect(response.parsed_body["data"]["metadata"]["generated_at"]).to eq(Time.current.iso8601)
          end
        end

        it "includes organization name" do
          get "/api/v1/reports", headers: headers
          expect(response.parsed_body["data"]["metadata"]["organization_name"]).to eq("Acme Corp")
        end
      end
    end

    describe "AI analysis status filtering" do
      let!(:ticket1) { Ticket.create!(organization: organization, upload: upload, subject: "T1") }
      let!(:ticket2) { Ticket.create!(organization: organization, upload: upload, subject: "T2") }
      let!(:ticket3) { Ticket.create!(organization: organization, upload: upload, subject: "T3") }

      before do
        AiAnalysis.create!(
          organization: organization, ticket: ticket1, status: "completed",
          sentiment: "positive", category: "general", confidence: 0.9,
          feature_request: true, bug_report: false, knowledge_gap: false,
          processed_at: Time.current
        )
        AiAnalysis.create!(
          organization: organization, ticket: ticket2, status: "pending"
        )
        AiAnalysis.create!(
          organization: organization, ticket: ticket3, status: "failed",
          error_message: "Something went wrong"
        )
      end

      it "only counts completed analyses in analyzed count" do
        get "/api/v1/reports", headers: headers
        expect(response.parsed_body["data"]["tickets"]["analyzed"]).to eq(1)
        expect(response.parsed_body["data"]["tickets"]["unanalyzed"]).to eq(2)
      end

      it "excludes pending analyses from sentiment distribution" do
        get "/api/v1/reports", headers: headers
        dist = response.parsed_body["data"]["sentiment"]["distribution"]
        expect(dist).to eq({ "positive" => 1 })
      end

      it "excludes failed analyses from classifications" do
        get "/api/v1/reports", headers: headers
        expect(response.parsed_body["data"]["classifications"]["feature_requests"]).to eq(1)
      end

      it "excludes non-completed analyses from category distribution" do
        get "/api/v1/reports", headers: headers
        expect(response.parsed_body["data"]["categories"]["distribution"]).to eq({ "general" => 1 })
      end
    end

    describe "tenant isolation" do
      let(:other_org) { Organization.create!(name: "Other Inc", slug: "other") }
      let(:other_upload) { Upload.create!(organization: other_org, filename: "other.csv") }

      before do
        # Our org data
        our_ticket = Ticket.create!(
          organization: organization, upload: upload, subject: "Ours",
          status: "open", priority: "high"
        )
        AiAnalysis.create!(
          organization: organization, ticket: our_ticket, status: "completed",
          sentiment: "negative", category: "billing", confidence: 0.9,
          feature_request: true, bug_report: true, knowledge_gap: true,
          processed_at: Time.current
        )

        # Other org data (should never appear)
        other_ticket = Ticket.create!(
          organization: other_org, upload: other_upload, subject: "Theirs",
          status: "closed", priority: "low"
        )
        AiAnalysis.create!(
          organization: other_org, ticket: other_ticket, status: "completed",
          sentiment: "positive", category: "general", confidence: 0.8,
          feature_request: false, bug_report: false, knowledge_gap: false,
          processed_at: Time.current
        )
      end

      it "only includes the authenticated user's organization tickets" do
        get "/api/v1/reports", headers: headers
        expect(response.parsed_body["data"]["tickets"]["total"]).to eq(1)
      end

      it "excludes other organization's analyses from sentiment" do
        get "/api/v1/reports", headers: headers
        dist = response.parsed_body["data"]["sentiment"]["distribution"]
        expect(dist).to eq({ "negative" => 1 })
        expect(dist).not_to have_key("positive")
      end

      it "excludes other organization's analyses from categories" do
        get "/api/v1/reports", headers: headers
        cats = response.parsed_body["data"]["categories"]["distribution"]
        expect(cats).to eq({ "billing" => 1 })
        expect(cats).not_to have_key("general")
      end

      it "excludes other organization's ticket statuses" do
        get "/api/v1/reports", headers: headers
        expect(response.parsed_body["data"]["status_distribution"]).to eq({ "open" => 1 })
      end
    end

    describe "null/blank values" do
      before do
        Ticket.create!(
          organization: organization, upload: upload, subject: "No status or priority",
          status: nil, priority: nil
        )
        ticket_with_analysis = Ticket.create!(
          organization: organization, upload: upload, subject: "Analyzed",
          status: "open", priority: nil
        )
        AiAnalysis.create!(
          organization: organization, ticket: ticket_with_analysis, status: "completed",
          sentiment: "neutral", category: nil, confidence: 0.7,
          feature_request: false, bug_report: false, knowledge_gap: false,
          processed_at: Time.current
        )
      end

      it "handles nil status in distribution" do
        get "/api/v1/reports", headers: headers
        dist = response.parsed_body["data"]["status_distribution"]
        expect(dist["open"]).to eq(1)
        # nil keys are serialized as empty string or null key
        expect(dist.values.sum).to eq(2)
      end

      it "handles nil priority in distribution" do
        get "/api/v1/reports", headers: headers
        dist = response.parsed_body["data"]["priority_distribution"]
        expect(dist.values.sum).to eq(2)
      end

      it "excludes nil/blank categories from category distribution" do
        get "/api/v1/reports", headers: headers
        dist = response.parsed_body["data"]["categories"]["distribution"]
        expect(dist).to eq({})
      end

      it "does not break the response" do
        get "/api/v1/reports", headers: headers
        expect(response).to have_http_status(:ok)
      end
    end

    describe "response shape" do
      it "returns expected top-level structure" do
        get "/api/v1/reports", headers: headers
        data = response.parsed_body["data"]
        expect(data.keys).to contain_exactly(
          "metadata", "tickets", "sentiment", "categories",
          "classifications", "status_distribution", "priority_distribution", "timeline"
        )
      end

      it "returns expected tickets structure" do
        get "/api/v1/reports", headers: headers
        tickets = response.parsed_body["data"]["tickets"]
        expect(tickets.keys).to contain_exactly("total", "analyzed", "unanalyzed")
      end

      it "returns expected sentiment structure" do
        get "/api/v1/reports", headers: headers
        sentiment = response.parsed_body["data"]["sentiment"]
        expect(sentiment.keys).to contain_exactly("distribution", "percentages")
      end

      it "returns expected categories structure" do
        get "/api/v1/reports", headers: headers
        categories = response.parsed_body["data"]["categories"]
        expect(categories.keys).to contain_exactly("distribution", "top")
      end

      it "returns expected classifications structure" do
        get "/api/v1/reports", headers: headers
        classifications = response.parsed_body["data"]["classifications"]
        expect(classifications.keys).to contain_exactly("feature_requests", "bug_reports", "knowledge_gaps")
      end

      it "returns expected metadata structure" do
        get "/api/v1/reports", headers: headers
        metadata = response.parsed_body["data"]["metadata"]
        expect(metadata.keys).to contain_exactly("generated_at", "organization_name")
      end
    end
  end
end
