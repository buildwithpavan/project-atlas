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
      user = described_class.new(email: nil, first_name: "Ada", last_name: "Lovelace", password: "password123")
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it "requires a valid email format" do
      user = described_class.new(email: "not-an-email", first_name: "Ada", last_name: "Lovelace", password: "password123")
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("is invalid")
    end

    it "accepts a valid email" do
      user = described_class.new(email: "ada@example.com", first_name: "Ada", last_name: "Lovelace", password: "password123")
      expect(user).to be_valid
    end

    it "requires first_name" do
      user = described_class.new(email: "ada@example.com", first_name: nil, last_name: "Lovelace", password: "password123")
      expect(user).not_to be_valid
      expect(user.errors[:first_name]).to include("can't be blank")
    end

    it "requires last_name" do
      user = described_class.new(email: "ada@example.com", first_name: "Ada", last_name: nil, password: "password123")
      expect(user).not_to be_valid
      expect(user.errors[:last_name]).to include("can't be blank")
    end
  end

  describe "password authentication" do
    let(:user) do
      described_class.new(
        email: "ada@example.com",
        first_name: "Ada",
        last_name: "Lovelace",
        password: "secure_password",
        password_confirmation: "secure_password"
      )
    end

    it "can be assigned a password" do
      expect(user).to be_valid
    end

    it "generates a password_digest that is not the plaintext password" do
      user.valid?
      expect(user.password_digest).to be_present
      expect(user.password_digest).not_to eq("secure_password")
    end

    it "authenticates with correct password" do
      expect(user.authenticate("secure_password")).to eq(user)
    end

    it "fails authentication with incorrect password" do
      expect(user.authenticate("wrong_password")).to be false
    end

    it "rejects password confirmation mismatch" do
      user.password_confirmation = "different_password"
      expect(user).not_to be_valid
      expect(user.errors[:password_confirmation]).to include("doesn't match Password")
    end

    it "requires password on new records" do
      user_without_password = described_class.new(
        email: "ada@example.com",
        first_name: "Ada",
        last_name: "Lovelace"
      )
      expect(user_without_password).not_to be_valid
      expect(user_without_password.errors[:password]).to include("can't be blank")
    end
  end
end
