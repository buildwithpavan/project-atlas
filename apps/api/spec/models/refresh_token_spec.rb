# frozen_string_literal: true

require "rails_helper"

RSpec.describe RefreshToken, type: :model do
  let(:user) do
    User.create!(
      email: "ada@example.com",
      first_name: "Ada",
      last_name: "Lovelace",
      password: "secure_password"
    )
  end

  def create_token(overrides = {})
    raw = RefreshToken.generate_token
    defaults = {
      user: user,
      token_digest: RefreshToken.digest(raw),
      family_id: SecureRandom.uuid,
      expires_at: 30.days.from_now
    }
    described_class.create!(defaults.merge(overrides))
  end

  describe "associations" do
    it "belongs to user" do
      association = described_class.reflect_on_association(:user)
      expect(association.macro).to eq(:belongs_to)
    end
  end

  describe "validations" do
    it "requires token_digest" do
      token = described_class.new(user: user, family_id: SecureRandom.uuid, expires_at: 1.day.from_now)
      expect(token).not_to be_valid
      expect(token.errors[:token_digest]).to include("can't be blank")
    end

    it "requires family_id" do
      token = described_class.new(user: user, token_digest: "abc", expires_at: 1.day.from_now)
      expect(token).not_to be_valid
      expect(token.errors[:family_id]).to include("can't be blank")
    end

    it "requires expires_at" do
      token = described_class.new(user: user, token_digest: "abc", family_id: SecureRandom.uuid)
      expect(token).not_to be_valid
      expect(token.errors[:expires_at]).to include("can't be blank")
    end

    it "enforces token_digest uniqueness" do
      raw = RefreshToken.generate_token
      digest = RefreshToken.digest(raw)
      create_token(token_digest: digest)

      duplicate = described_class.new(
        user: user,
        token_digest: digest,
        family_id: SecureRandom.uuid,
        expires_at: 30.days.from_now
      )
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:token_digest]).to include("has already been taken")
    end
  end

  describe ".generate_token" do
    it "returns a string with sufficient length" do
      token = described_class.generate_token
      expect(token).to be_a(String)
      expect(token.length).to be >= 32
    end

    it "generates unique tokens" do
      tokens = Array.new(10) { described_class.generate_token }
      expect(tokens.uniq.length).to eq(10)
    end
  end

  describe ".digest" do
    it "produces a deterministic digest for the same input" do
      raw = "test_token_value"
      expect(described_class.digest(raw)).to eq(described_class.digest(raw))
    end

    it "produces a different digest than the raw token" do
      raw = "test_token_value"
      expect(described_class.digest(raw)).not_to eq(raw)
    end
  end

  describe "#expired?" do
    it "returns false when expires_at is in the future" do
      token = create_token(expires_at: 1.day.from_now)
      expect(token).not_to be_expired
    end

    it "returns true when expires_at is in the past" do
      token = create_token(expires_at: 1.day.ago)
      expect(token).to be_expired
    end
  end

  describe "#revoked?" do
    it "returns false when revoked_at is nil" do
      token = create_token
      expect(token).not_to be_revoked
    end

    it "returns true when revoked_at is set" do
      token = create_token
      token.revoke!
      expect(token).to be_revoked
    end
  end

  describe "#revoke!" do
    it "sets revoked_at" do
      token = create_token
      token.revoke!
      expect(token.reload.revoked_at).to be_present
    end
  end

  describe ".revoke_family!" do
    it "revokes all active tokens in the family" do
      family = SecureRandom.uuid
      t1 = create_token(family_id: family)
      t2 = create_token(family_id: family)
      other = create_token(family_id: SecureRandom.uuid)

      described_class.revoke_family!(family)

      expect(t1.reload).to be_revoked
      expect(t2.reload).to be_revoked
      expect(other.reload).not_to be_revoked
    end
  end
end
