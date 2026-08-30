# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::DetectThemes, type: :service do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme") }
  let(:user) { User.create!(email: "user@example.com", first_name: "A", last_name: "B", password: "password123") }
  let!(:membership) { Membership.create!(user: user, organization: organization, role: "owner") }
  let(:upload) { Upload.create!(organization: organization, filename: "test.csv") }

  def create_analyzed_ticket(subject:, sentiment: "negative", category: "billing", summary: "Test summary")
    ticket = Ticket.create!(organization: organization, upload: upload, subject: subject)
    AiAnalysis.create!(
      organization: organization,
      ticket: ticket,
      status: "completed",
      sentiment: sentiment,
      category: category,
      summary: summary,
      confidence: 0.9,
      processed_at: Time.current
    )
    ticket
  end

  describe "#call" do
    context "with fewer than MIN_TICKETS_FOR_DETECTION analyses" do
      it "returns zero counts without calling the AI" do
        3.times { |i| create_analyzed_ticket(subject: "Ticket #{i}") }

        result = described_class.call(organization: organization)

        expect(result.themes_created).to eq(0)
        expect(result.themes_updated).to eq(0)
        expect(result.tickets_analyzed).to eq(0)
      end
    end

    context "with sufficient analyses" do
      let!(:tickets) do
        6.times.map { |i| create_analyzed_ticket(subject: "Billing issue #{i}", summary: "Customer has billing problem #{i}") }
      end

      let(:mock_theme) do
        instance_double(
          Ai::Schemas::DetectedTheme,
          title: "Recurring Billing Issues",
          description: "Multiple customers reporting billing problems",
          severity: :high,
          evidence_summary: "6 tickets mention billing issues",
          recommended_action: "Investigate billing system",
          ticket_ids: tickets.first(3).map { |t| t.id.to_s }
        )
      end

      let(:mock_output) do
        instance_double(Ai::Schemas::ThemeDetectionOutput, themes: [mock_theme])
      end

      before do
        allow(Ai::Providers::Openai).to receive(:detect_themes).and_return(mock_output)
      end

      it "calls OpenAI with ticket data and creates themes" do
        result = described_class.call(organization: organization)

        expect(result.themes_created).to eq(1)
        expect(result.tickets_analyzed).to eq(6)

        theme = organization.themes.first
        expect(theme.title).to eq("Recurring Billing Issues")
        expect(theme.severity).to eq("high")
        expect(theme.ticket_count).to eq(3)
        expect(theme.theme_memberships.count).to eq(3)
      end

      it "passes ticket data to the AI provider" do
        described_class.call(organization: organization)

        expect(Ai::Providers::Openai).to have_received(:detect_themes) do |args|
          input = args[:input]
          system_msg = input.find { |m| m[:role] == :system }
          user_msg = input.find { |m| m[:role] == :user }

          expect(system_msg[:content]).to include("Voceive")
          expect(user_msg[:content]).to include("Billing issue")
        end
      end

      it "does not create themes with fewer than 2 supporting tickets" do
        single_ticket_theme = instance_double(
          Ai::Schemas::DetectedTheme,
          title: "Isolated Issue",
          description: "Only one ticket",
          severity: :low,
          evidence_summary: "Just one ticket",
          recommended_action: "Monitor",
          ticket_ids: [tickets.first.id.to_s]
        )

        allow(Ai::Providers::Openai).to receive(:detect_themes)
          .and_return(instance_double(Ai::Schemas::ThemeDetectionOutput, themes: [single_ticket_theme]))

        result = described_class.call(organization: organization)
        expect(result.themes_created).to eq(0)
      end

      it "filters out invalid ticket IDs" do
        theme_with_bad_ids = instance_double(
          Ai::Schemas::DetectedTheme,
          title: "Mixed IDs Theme",
          description: "Has invalid IDs",
          severity: :medium,
          evidence_summary: "Some evidence",
          recommended_action: "Fix things",
          ticket_ids: [tickets.first.id.to_s, tickets.second.id.to_s, "invalid-uuid"]
        )

        allow(Ai::Providers::Openai).to receive(:detect_themes)
          .and_return(instance_double(Ai::Schemas::ThemeDetectionOutput, themes: [theme_with_bad_ids]))

        result = described_class.call(organization: organization)
        expect(result.themes_created).to eq(1)
        expect(organization.themes.first.ticket_count).to eq(2)
      end
    end

    context "updating existing themes" do
      let!(:tickets) do
        6.times.map { |i| create_analyzed_ticket(subject: "Issue #{i}") }
      end

      let!(:existing_theme) do
        Theme.create!(
          organization: organization,
          title: "Existing Issue",
          description: "Old description",
          severity: "low",
          ticket_count: 2,
          first_seen_at: 5.days.ago,
          last_seen_at: 2.days.ago
        )
      end

      it "updates existing themes instead of creating duplicates" do
        mock_theme = instance_double(
          Ai::Schemas::DetectedTheme,
          title: "Existing Issue",
          description: "Updated description",
          severity: :high,
          evidence_summary: "More evidence now",
          recommended_action: "Take action",
          ticket_ids: tickets.first(3).map { |t| t.id.to_s }
        )

        allow(Ai::Providers::Openai).to receive(:detect_themes)
          .and_return(instance_double(Ai::Schemas::ThemeDetectionOutput, themes: [mock_theme]))

        result = described_class.call(organization: organization)

        expect(result.themes_created).to eq(0)
        expect(result.themes_updated).to eq(1)

        existing_theme.reload
        expect(existing_theme.description).to eq("Updated description")
        expect(existing_theme.severity).to eq("high")
        expect(existing_theme.ticket_count).to eq(3)
        expect(existing_theme.first_seen_at).to be_within(1.second).of(5.days.ago) # preserved
      end
    end

    context "AI failure handling" do
      let!(:tickets) do
        6.times.map { |i| create_analyzed_ticket(subject: "Issue #{i}") }
      end

      it "propagates AI errors" do
        allow(Ai::Providers::Openai).to receive(:detect_themes)
          .and_raise(StandardError, "AI service unavailable")

        expect {
          described_class.call(organization: organization)
        }.to raise_error(StandardError, "AI service unavailable")

        expect(organization.themes.count).to eq(0)
      end
    end
  end
end
