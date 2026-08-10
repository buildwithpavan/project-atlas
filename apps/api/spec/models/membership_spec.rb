# frozen_string_literal: true

require "rails_helper"

RSpec.describe Membership, type: :model do
  describe "associations" do
    it "belongs to user" do
      association = described_class.reflect_on_association(:user)
      expect(association.macro).to eq(:belongs_to)
    end

    it "belongs to organization" do
      association = described_class.reflect_on_association(:organization)
      expect(association.macro).to eq(:belongs_to)
    end
  end

  describe "validations" do
    it "requires a role" do
      membership = described_class.new(role: nil)
      membership.valid?
      expect(membership.errors[:role]).to include("can't be blank")
    end

    it "rejects an invalid role" do
      membership = described_class.new(role: "superuser")
      membership.valid?
      expect(membership.errors[:role]).to include("is not included in the list")
    end

    %w[owner admin member viewer].each do |valid_role|
      it "accepts role '#{valid_role}'" do
        org = Organization.create!(name: "Org", slug: "org-#{valid_role}")
        user = User.create!(email: "#{valid_role}@example.com", first_name: "A", last_name: "B", password: "password123")
        membership = described_class.new(user: user, organization: org, role: valid_role)
        expect(membership).to be_valid
      end
    end
  end

  describe "ROLES constant" do
    it "defines exactly owner, admin, member, viewer" do
      expect(Membership::ROLES).to eq(%w[owner admin member viewer])
    end
  end
end
