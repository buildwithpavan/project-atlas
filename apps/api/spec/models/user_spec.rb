# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  describe "associations" do
    it "has many memberships" do
      association = described_class.reflect_on_association(:memberships)
      expect(association.macro).to eq(:has_many)
      expect(association.options[:dependent]).to eq(:destroy)
    end

    it "has many organizations through memberships" do
      association = described_class.reflect_on_association(:organizations)
      expect(association.macro).to eq(:has_many)
      expect(association.options[:through]).to eq(:memberships)
    end
  end

  describe "validations" do
    it "requires email" do
      user = described_class.new(email: nil, first_name: "Ada", last_name: "Lovelace", password_digest: "x")
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it "requires a valid email format" do
      user = described_class.new(email: "not-an-email", first_name: "Ada", last_name: "Lovelace", password_digest: "x")
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("is invalid")
    end

    it "accepts a valid email" do
      user = described_class.new(email: "ada@example.com", first_name: "Ada", last_name: "Lovelace", password_digest: "x")
      expect(user).to be_valid
    end

    it "requires first_name" do
      user = described_class.new(email: "ada@example.com", first_name: nil, last_name: "Lovelace", password_digest: "x")
      expect(user).not_to be_valid
      expect(user.errors[:first_name]).to include("can't be blank")
    end

    it "requires last_name" do
      user = described_class.new(email: "ada@example.com", first_name: "Ada", last_name: nil, password_digest: "x")
      expect(user).not_to be_valid
      expect(user.errors[:last_name]).to include("can't be blank")
    end
  end
end
