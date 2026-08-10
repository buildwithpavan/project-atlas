# frozen_string_literal: true

require "rails_helper"

RSpec.describe Organization, type: :model do
  describe "associations" do
    it "has many memberships" do
      association = described_class.reflect_on_association(:memberships)
      expect(association.macro).to eq(:has_many)
      expect(association.options[:dependent]).to eq(:destroy)
    end

    it "has many users through memberships" do
      association = described_class.reflect_on_association(:users)
      expect(association.macro).to eq(:has_many)
      expect(association.options[:through]).to eq(:memberships)
    end

    it "has many uploads" do
      association = described_class.reflect_on_association(:uploads)
      expect(association.macro).to eq(:has_many)
      expect(association.options[:dependent]).to eq(:destroy)
    end

    it "has many tickets" do
      association = described_class.reflect_on_association(:tickets)
      expect(association.macro).to eq(:has_many)
      expect(association.options[:dependent]).to eq(:destroy)
    end
  end

  describe "user access through memberships" do
    it "returns users associated via memberships" do
      org = described_class.create!(name: "Acme", slug: "acme")
      user = User.create!(email: "user@example.com", first_name: "A", last_name: "B", password: "password123")
      Membership.create!(user: user, organization: org, role: "member")

      expect(org.users).to include(user)
    end
  end

  describe "upload relationship" do
    it "returns uploads belonging to the organization" do
      org = described_class.create!(name: "Acme", slug: "acme")
      upload = Upload.create!(organization: org, filename: "export.csv")

      expect(org.uploads).to include(upload)
    end
  end

  describe "ticket relationship" do
    it "returns tickets belonging to the organization" do
      org = described_class.create!(name: "Acme", slug: "acme")
      upload = Upload.create!(organization: org, filename: "export.csv")
      ticket = Ticket.create!(organization: org, upload: upload, subject: "Help")

      expect(org.tickets).to include(ticket)
    end
  end
end
