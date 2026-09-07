# frozen_string_literal: true

require "rails_helper"

RSpec.describe Identity::IssueRefreshToken, type: :service do
  let(:user) do
    User.create!(
      email: "ada@example.com",
      first_name: "Ada",
      last_name: "Lovelace",
      password: "secure_password"
    )
  end

  describe ".call" do
    it "returns a raw token" do
      result = described_class.call(user: user)
      expect(result[:raw_token]).to be_present
      expect(result[:raw_token].length).to be >= 32
    end

    it "persists a RefreshToken record" do
      expect { described_class.call(user: user) }.to change(RefreshToken, :count).by(1)
    end

    it "stores only the digest, not the raw token" do
      result = described_class.call(user: user)
      record = result[:record]
      expect(record.token_digest).to be_present
      expect(record.token_digest).not_to eq(result[:raw_token])
      expect(record.token_digest).to eq(RefreshToken.digest(result[:raw_token]))
    end

    it "generates a new family_id when none provided" do
      result = described_class.call(user: user)
      expect(result[:record].family_id).to be_present
    end

    it "preserves the provided family_id" do
      family = SecureRandom.uuid
      result = described_class.call(user: user, family_id: family)
      expect(result[:record].family_id).to eq(family)
    end

    it "sets expires_at in the future" do
      result = described_class.call(user: user)
      expect(result[:record].expires_at).to be > Time.current
    end
  end
end
