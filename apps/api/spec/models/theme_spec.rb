# frozen_string_literal: true

require "rails_helper"

RSpec.describe Theme, type: :model do
  let(:organization) { Organization.create!(name: "Test Org", slug: "test-org") }

  describe "validations" do
    it "requires title" do
      theme = Theme.new(organization: organization, description: "desc", status: "active", severity: "medium")
      expect(theme).not_to be_valid
      expect(theme.errors[:title]).to include("can't be blank")
    end

    it "requires description" do
      theme = Theme.new(organization: organization, title: "Test", status: "active", severity: "medium")
      expect(theme).not_to be_valid
      expect(theme.errors[:description]).to include("can't be blank")
    end

    it "validates status inclusion" do
      theme = Theme.new(organization: organization, title: "Test", description: "desc", status: "invalid", severity: "medium")
      expect(theme).not_to be_valid
      expect(theme.errors[:status]).to include("is not included in the list")
    end

    it "validates severity inclusion" do
      theme = Theme.new(organization: organization, title: "Test", description: "desc", status: "active", severity: "invalid")
      expect(theme).not_to be_valid
      expect(theme.errors[:severity]).to include("is not included in the list")
    end

    it "accepts valid statuses" do
      %w[active resolved archived].each do |status|
        theme = Theme.new(organization: organization, title: "Test", description: "desc", status: status, severity: "medium")
        expect(theme).to be_valid, "expected status '#{status}' to be valid"
      end
    end

    it "accepts valid severities" do
      %w[low medium high critical].each do |severity|
        theme = Theme.new(organization: organization, title: "Test", description: "desc", status: "active", severity: severity)
        expect(theme).to be_valid, "expected severity '#{severity}' to be valid"
      end
    end
  end

  describe "associations" do
    it "belongs to organization" do
      theme = Theme.new(organization: organization, title: "Test", description: "desc")
      expect(theme.organization).to eq(organization)
    end

    it "has many theme_memberships" do
      expect(Theme.reflect_on_association(:theme_memberships).macro).to eq(:has_many)
    end

    it "has many tickets through theme_memberships" do
      expect(Theme.reflect_on_association(:tickets).macro).to eq(:has_many)
    end
  end

  describe "scopes" do
    before do
      Theme.create!(organization: organization, title: "Active", description: "desc", status: "active", severity: "high", ticket_count: 5)
      Theme.create!(organization: organization, title: "Resolved", description: "desc", status: "resolved", severity: "low", ticket_count: 2)
    end

    it ".active returns only active themes" do
      expect(organization.themes.active.pluck(:title)).to eq(["Active"])
    end

    it ".by_severity filters by severity" do
      expect(organization.themes.by_severity("high").pluck(:title)).to eq(["Active"])
    end

    it ".by_ticket_count orders by ticket_count desc" do
      expect(organization.themes.by_ticket_count.pluck(:title)).to eq(["Active", "Resolved"])
    end
  end
end
