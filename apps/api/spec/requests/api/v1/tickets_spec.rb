# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tickets API", type: :request do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme") }
  let(:user) do
    User.create!(email: "user@example.com", first_name: "A", last_name: "B", password: "password123")
  end
  let!(:membership) { Membership.create!(user: user, organization: organization, role: "member") }
  let(:access_token) { Identity::AccessToken.encode(user) }
  let(:headers) { { "Authorization" => "Bearer #{access_token}" } }
  let(:upload) { Upload.create!(organization: organization, filename: "test.csv") }

  describe "GET /api/v1/tickets" do
    describe "authentication" do
      it "rejects unauthenticated requests" do
        get "/api/v1/tickets"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe "authorization" do
      it "rejects users with no organization membership" do
        orphan = User.create!(email: "orphan@example.com", first_name: "O", last_name: "P", password: "password123")
        token = Identity::AccessToken.encode(orphan)
        get "/api/v1/tickets", headers: { "Authorization" => "Bearer #{token}" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe "tenant isolation" do
      let(:other_org) { Organization.create!(name: "Other", slug: "other") }
      let(:other_upload) { Upload.create!(organization: other_org, filename: "other.csv") }

      before do
        Ticket.create!(organization: organization, upload: upload, subject: "Our ticket")
        Ticket.create!(organization: other_org, upload: other_upload, subject: "Their ticket")
      end

      it "only returns tickets belonging to the user's organization" do
        get "/api/v1/tickets", headers: headers
        expect(response).to have_http_status(:ok)
        data = response.parsed_body["data"]
        expect(data.length).to eq(1)
        expect(data.first["subject"]).to eq("Our ticket")
      end
    end

    describe "pagination" do
      before do
        30.times { |i| Ticket.create!(organization: organization, upload: upload, subject: "Ticket #{i}") }
      end

      it "returns 25 results per page by default" do
        get "/api/v1/tickets", headers: headers
        expect(response.parsed_body["data"].length).to eq(25)
      end

      it "includes pagination meta" do
        get "/api/v1/tickets", headers: headers
        meta = response.parsed_body["meta"]
        expect(meta["page"]).to eq(1)
        expect(meta["per_page"]).to eq(25)
        expect(meta["total"]).to eq(30)
        expect(meta["total_pages"]).to eq(2)
      end

      it "supports custom page and per_page" do
        get "/api/v1/tickets", params: { page: 2, per_page: 10 }, headers: headers
        expect(response.parsed_body["data"].length).to eq(10)
        expect(response.parsed_body["meta"]["page"]).to eq(2)
      end

      it "caps per_page at 100" do
        get "/api/v1/tickets", params: { per_page: 200 }, headers: headers
        expect(response.parsed_body["meta"]["per_page"]).to eq(100)
      end

      it "enforces minimum per_page of 1" do
        get "/api/v1/tickets", params: { per_page: 0 }, headers: headers
        expect(response.parsed_body["meta"]["per_page"]).to eq(1)
      end
    end

    describe "search" do
      before do
        Ticket.create!(organization: organization, upload: upload, subject: "Login bug", description: "Cannot login")
        Ticket.create!(organization: organization, upload: upload, subject: "Billing question", customer_name: "Alice")
        Ticket.create!(organization: organization, upload: upload, subject: "Feature idea")
      end

      it "searches by subject" do
        get "/api/v1/tickets", params: { search: "Login" }, headers: headers
        data = response.parsed_body["data"]
        expect(data.length).to eq(1)
        expect(data.first["subject"]).to eq("Login bug")
      end

      it "searches by description" do
        get "/api/v1/tickets", params: { search: "Cannot" }, headers: headers
        data = response.parsed_body["data"]
        expect(data.length).to eq(1)
        expect(data.first["subject"]).to eq("Login bug")
      end

      it "searches by customer_name" do
        get "/api/v1/tickets", params: { search: "Alice" }, headers: headers
        data = response.parsed_body["data"]
        expect(data.length).to eq(1)
        expect(data.first["subject"]).to eq("Billing question")
      end

      it "is case-insensitive" do
        get "/api/v1/tickets", params: { search: "login" }, headers: headers
        expect(response.parsed_body["data"].length).to eq(1)
      end

      it "handles SQL special characters safely" do
        Ticket.create!(organization: organization, upload: upload, subject: "100% discount")
        get "/api/v1/tickets", params: { search: "100%" }, headers: headers
        data = response.parsed_body["data"]
        expect(data.length).to eq(1)
        expect(data.first["subject"]).to eq("100% discount")
      end
    end

    describe "filtering" do
      before do
        Ticket.create!(organization: organization, upload: upload, subject: "T1", status: "open", priority: "high", category: "billing")
        Ticket.create!(organization: organization, upload: upload, subject: "T2", status: "closed", priority: "low", category: "support")
        Ticket.create!(organization: organization, upload: upload, subject: "T3", status: "open", priority: "low", category: "billing")
      end

      it "filters by status" do
        get "/api/v1/tickets", params: { status: "open" }, headers: headers
        expect(response.parsed_body["data"].length).to eq(2)
      end

      it "filters by priority" do
        get "/api/v1/tickets", params: { priority: "high" }, headers: headers
        data = response.parsed_body["data"]
        expect(data.length).to eq(1)
        expect(data.first["subject"]).to eq("T1")
      end

      it "filters by category" do
        get "/api/v1/tickets", params: { category: "billing" }, headers: headers
        expect(response.parsed_body["data"].length).to eq(2)
      end

      it "combines multiple filters" do
        get "/api/v1/tickets", params: { status: "open", priority: "low" }, headers: headers
        data = response.parsed_body["data"]
        expect(data.length).to eq(1)
        expect(data.first["subject"]).to eq("T3")
      end
    end

    describe "ordering" do
      it "returns tickets in reverse chronological order" do
        t1 = Ticket.create!(organization: organization, upload: upload, subject: "First")
        t2 = Ticket.create!(organization: organization, upload: upload, subject: "Second")
        get "/api/v1/tickets", headers: headers
        data = response.parsed_body["data"]
        expect(data.first["id"]).to eq(t2.id)
        expect(data.last["id"]).to eq(t1.id)
      end
    end

    describe "response shape" do
      before do
        Ticket.create!(
          organization: organization, upload: upload,
          subject: "Help", status: "open", priority: "high",
          category: "billing", customer_name: "Jane", customer_email: "jane@example.com"
        )
      end

      it "returns expected fields" do
        get "/api/v1/tickets", headers: headers
        ticket = response.parsed_body["data"].first
        expect(ticket.keys).to contain_exactly(
          "id", "subject", "status", "priority", "category",
          "customer_name", "customer_email", "created_at", "updated_at"
        )
      end
    end
  end

  describe "GET /api/v1/tickets/:id" do
    let!(:ticket) do
      Ticket.create!(
        organization: organization, upload: upload,
        subject: "Login issue", description: "Cannot login to the system",
        status: "open", priority: "high", category: "technical",
        customer_name: "Jane", customer_email: "jane@example.com"
      )
    end

    describe "authentication" do
      it "rejects unauthenticated requests" do
        get "/api/v1/tickets/#{ticket.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe "tenant isolation" do
      let(:other_org) { Organization.create!(name: "Other", slug: "other") }
      let(:other_upload) { Upload.create!(organization: other_org, filename: "other.csv") }
      let(:other_ticket) { Ticket.create!(organization: other_org, upload: other_upload, subject: "Secret") }

      it "returns 404 for tickets belonging to another organization" do
        get "/api/v1/tickets/#{other_ticket.id}", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    describe "not found" do
      it "returns 404 for non-existent ticket" do
        get "/api/v1/tickets/#{SecureRandom.uuid}", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    describe "successful response" do
      it "returns the ticket detail" do
        get "/api/v1/tickets/#{ticket.id}", headers: headers
        expect(response).to have_http_status(:ok)
        data = response.parsed_body["data"]
        expect(data["id"]).to eq(ticket.id)
        expect(data["subject"]).to eq("Login issue")
        expect(data["description"]).to eq("Cannot login to the system")
        expect(data["upload_id"]).to eq(upload.id)
      end

      it "includes ai_analysis when present" do
        AiAnalysis.create!(
          organization: organization, ticket: ticket,
          status: "completed", sentiment: "negative",
          summary: "User cannot login", category: "account",
          confidence: 0.92, feature_request: false,
          bug_report: true, knowledge_gap: false,
          processed_at: Time.current
        )

        get "/api/v1/tickets/#{ticket.id}", headers: headers
        ai = response.parsed_body["data"]["ai_analysis"]
        expect(ai["status"]).to eq("completed")
        expect(ai["sentiment"]).to eq("negative")
        expect(ai["summary"]).to eq("User cannot login")
        expect(ai["category"]).to eq("account")
        expect(ai["confidence"]).to eq(0.92)
        expect(ai["feature_request"]).to be(false)
        expect(ai["bug_report"]).to be(true)
        expect(ai["knowledge_gap"]).to be(false)
        expect(ai["processed_at"]).to be_present
      end

      it "returns null ai_analysis when not analyzed" do
        get "/api/v1/tickets/#{ticket.id}", headers: headers
        expect(response.parsed_body["data"]["ai_analysis"]).to be_nil
      end

      it "returns expected fields" do
        get "/api/v1/tickets/#{ticket.id}", headers: headers
        data = response.parsed_body["data"]
        expect(data.keys).to contain_exactly(
          "id", "subject", "description", "status", "priority", "category",
          "customer_name", "customer_email", "upload_id", "ai_analysis",
          "created_at", "updated_at"
        )
      end
    end
  end
end
