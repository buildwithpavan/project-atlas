# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Themes API", type: :request do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme") }
  let(:user) do
    User.create!(email: "user@example.com", first_name: "A", last_name: "B", password: "password123")
  end
  let!(:membership) { Membership.create!(user: user, organization: organization, role: "member") }
  let(:access_token) { Identity::AccessToken.encode(user) }
  let(:headers) { { "Authorization" => "Bearer #{access_token}" } }
  let(:upload) { Upload.create!(organization: organization, filename: "test.csv") }

  # ── GET /api/v1/themes ───────────────────────────────────────────────

  describe "GET /api/v1/themes" do
    it "rejects unauthenticated requests" do
      get "/api/v1/themes"
      expect(response).to have_http_status(:unauthorized)
    end

    context "with no themes" do
      it "returns an empty array" do
        get "/api/v1/themes", headers: headers
        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["data"]).to eq([])
        expect(body["meta"]["total"]).to eq(0)
      end
    end

    context "with themes" do
      before do
        Theme.create!(
          organization: organization,
          title: "Billing Issues",
          description: "Multiple customers reporting billing problems",
          severity: "high",
          ticket_count: 5,
          first_seen_at: 2.days.ago,
          last_seen_at: 1.day.ago
        )
        Theme.create!(
          organization: organization,
          title: "Slow Performance",
          description: "Performance degradation reports",
          severity: "medium",
          ticket_count: 3,
          first_seen_at: 3.days.ago,
          last_seen_at: Time.current
        )
      end

      it "returns all active themes ordered by ticket count" do
        get "/api/v1/themes", headers: headers
        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["data"].length).to eq(2)
        expect(body["data"].first["title"]).to eq("Billing Issues")
        expect(body["data"].first["severity"]).to eq("high")
        expect(body["data"].first["ticket_count"]).to eq(5)
      end

      it "filters by severity" do
        get "/api/v1/themes", params: { severity: "high" }, headers: headers
        body = response.parsed_body
        expect(body["data"].length).to eq(1)
        expect(body["data"].first["title"]).to eq("Billing Issues")
      end

      it "filters by status" do
        Theme.create!(
          organization: organization,
          title: "Resolved Theme",
          description: "Old issue",
          status: "resolved",
          severity: "low",
          ticket_count: 1
        )

        get "/api/v1/themes", params: { status: "resolved" }, headers: headers
        body = response.parsed_body
        expect(body["data"].length).to eq(1)
        expect(body["data"].first["title"]).to eq("Resolved Theme")
      end
    end

    it "does not return themes from other organizations" do
      other_org = Organization.create!(name: "Other", slug: "other")
      Theme.create!(organization: other_org, title: "Other Theme", description: "desc", severity: "low", ticket_count: 1)

      get "/api/v1/themes", headers: headers
      body = response.parsed_body
      expect(body["data"]).to be_empty
    end
  end

  # ── GET /api/v1/themes/:id ───────────────────────────────────────────

  describe "GET /api/v1/themes/:id" do
    let(:theme) do
      Theme.create!(
        organization: organization,
        title: "Payment Failures",
        description: "Recurring payment processing issues",
        severity: "critical",
        ticket_count: 4,
        evidence_summary: "4 tickets mention failed payments",
        recommended_action: "Investigate payment gateway integration",
        first_seen_at: 3.days.ago,
        last_seen_at: Time.current
      )
    end

    let(:ticket1) { Ticket.create!(organization: organization, upload: upload, subject: "Payment failed") }
    let(:ticket2) { Ticket.create!(organization: organization, upload: upload, subject: "Can't pay invoice") }

    before do
      ThemeMembership.create!(theme: theme, ticket: ticket1, organization: organization, relevance_score: 0.95, evidence_text: "Payment processing error")
      ThemeMembership.create!(theme: theme, ticket: ticket2, organization: organization, relevance_score: 0.87, evidence_text: "Invoice payment failure")
    end

    it "returns theme with supporting tickets" do
      get "/api/v1/themes/#{theme.id}", headers: headers
      expect(response).to have_http_status(:ok)

      body = response.parsed_body
      data = body["data"]
      expect(data["title"]).to eq("Payment Failures")
      expect(data["severity"]).to eq("critical")
      expect(data["evidence_summary"]).to eq("4 tickets mention failed payments")
      expect(data["recommended_action"]).to eq("Investigate payment gateway integration")
      expect(data["tickets"].length).to eq(2)
      expect(data["tickets"].first["subject"]).to be_present
      expect(data["tickets"].first["relevance_score"]).to be_present
    end

    it "returns 404 for non-existent theme" do
      get "/api/v1/themes/#{SecureRandom.uuid}", headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for theme in another organization" do
      other_org = Organization.create!(name: "Other", slug: "other")
      other_theme = Theme.create!(organization: other_org, title: "Other", description: "desc", severity: "low", ticket_count: 1)

      get "/api/v1/themes/#{other_theme.id}", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ── POST /api/v1/themes/detect ───────────────────────────────────────

  describe "POST /api/v1/themes/detect" do
    it "rejects unauthenticated requests" do
      post "/api/v1/themes/detect"
      expect(response).to have_http_status(:unauthorized)
    end

    context "as an authorized owner" do
      let(:owner) do
        User.create!(email: "owner@example.com", first_name: "O", last_name: "W", password: "password123")
      end
      let!(:owner_membership) { Membership.create!(user: owner, organization: organization, role: "owner") }
      let(:owner_token) { Identity::AccessToken.encode(owner) }
      let(:owner_headers) { { "Authorization" => "Bearer #{owner_token}" } }

      it "enqueues a DetectThemesJob and returns 202" do
        expect {
          post "/api/v1/themes/detect", headers: owner_headers
        }.to have_enqueued_job(DetectThemesJob).with(organization.id)

        expect(response).to have_http_status(:accepted)
        expect(response.parsed_body["data"]["message"]).to eq("Theme detection started")
      end
    end

    context "as a viewer" do
      let(:viewer) do
        User.create!(email: "viewer@example.com", first_name: "V", last_name: "W", password: "password123")
      end
      let!(:viewer_membership) { Membership.create!(user: viewer, organization: organization, role: "viewer") }
      let(:viewer_token) { Identity::AccessToken.encode(viewer) }
      let(:viewer_headers) { { "Authorization" => "Bearer #{viewer_token}" } }

      it "rejects detect for viewers" do
        post "/api/v1/themes/detect", headers: viewer_headers
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
