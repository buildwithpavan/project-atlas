# frozen_string_literal: true

require "rails_helper"

RSpec.describe ThemeMembership, type: :model do
  let(:organization) { Organization.create!(name: "Test Org", slug: "test-org") }
  let(:user) { User.create!(email: "test@example.com", first_name: "Test", last_name: "User", password: "password123", password_confirmation: "password123") }
  let(:upload) { Upload.create!(organization: organization, filename: "test.csv", uploaded_by: user) }
  let(:ticket) { Ticket.create!(organization: organization, upload: upload, subject: "Test ticket") }
  let(:theme) { Theme.create!(organization: organization, title: "Test Theme", description: "desc") }

  describe "validations" do
    it "enforces uniqueness of theme_id + ticket_id" do
      ThemeMembership.create!(theme: theme, ticket: ticket, organization: organization)
      duplicate = ThemeMembership.new(theme: theme, ticket: ticket, organization: organization)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:theme_id]).to include("has already been taken")
    end

    it "validates relevance_score range" do
      membership = ThemeMembership.new(theme: theme, ticket: ticket, organization: organization, relevance_score: 1.5)
      expect(membership).not_to be_valid
    end

    it "allows nil relevance_score" do
      membership = ThemeMembership.new(theme: theme, ticket: ticket, organization: organization, relevance_score: nil)
      expect(membership).to be_valid
    end
  end

  describe "associations" do
    it "belongs to theme" do
      membership = ThemeMembership.new(theme: theme, ticket: ticket, organization: organization)
      expect(membership.theme).to eq(theme)
    end

    it "belongs to ticket" do
      membership = ThemeMembership.new(theme: theme, ticket: ticket, organization: organization)
      expect(membership.ticket).to eq(ticket)
    end
  end
end
