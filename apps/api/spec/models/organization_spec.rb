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
  end

  describe "user access through memberships" do
    it "returns users associated via memberships" do
      org = described_class.create!(name: "Acme", slug: "acme")
      user = User.create!(email: "user@example.com", first_name: "A", last_name: "B", password_digest: "x")
      Membership.create!(user: user, organization: org, role: "member")

      expect(org.users).to include(user)
    end
  end
end
