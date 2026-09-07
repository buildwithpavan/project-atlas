# frozen_string_literal: true

require "rails_helper"

RSpec.describe Identity::Logout, type: :service do
  let(:user) do
    User.create!(
      email: "ada@example.com",
      first_name: "Ada",
      last_name: "Lovelace",
      password: "secure_password"
    )
  end

  def issue_token(user:, family_id: nil)
    Identity::IssueRefreshToken.call(user: user, family_id: family_id)
  end

  describe ".call" do
    context "with a valid refresh token" do
      it "revokes the token family" do
        issued = issue_token(user: user)
        described_class.call(refresh_token: issued[:raw_token])

        expect(issued[:record].reload).to be_revoked
      end

      it "revokes all active tokens in the family" do
        family = SecureRandom.uuid
        t1 = issue_token(user: user, family_id: family)
        t2 = issue_token(user: user, family_id: family)

        described_class.call(refresh_token: t1[:raw_token])

        expect(t1[:record].reload).to be_revoked
        expect(t2[:record].reload).to be_revoked
      end

      it "does not revoke unrelated token families" do
        issued = issue_token(user: user)
        other = issue_token(user: user)

        described_class.call(refresh_token: issued[:raw_token])

        expect(other[:record].reload).not_to be_revoked
      end

      it "does not issue a new access token" do
        issued = issue_token(user: user)
        result = described_class.call(refresh_token: issued[:raw_token])

        expect(result).not_to be_a(Hash)
        expect(result).not_to respond_to(:access_token) if result.respond_to?(:access_token)
      end

      it "does not issue a new refresh token" do
        issued = issue_token(user: user)

        expect {
          described_class.call(refresh_token: issued[:raw_token])
        }.not_to change(RefreshToken, :count)
      end

      it "does not persist the raw refresh token" do
        issued = issue_token(user: user)
        described_class.call(refresh_token: issued[:raw_token])

        expect(RefreshToken.where(token_digest: issued[:raw_token]).count).to eq(0)
      end
    end

    context "with an unknown refresh token" do
      it "raises UnauthorizedError" do
        expect {
          described_class.call(refresh_token: "totally_unknown_token")
        }.to raise_error(UnauthorizedError, "Invalid refresh token")
      end
    end

    context "with a missing refresh token" do
      it "raises UnauthorizedError" do
        expect {
          described_class.call(refresh_token: nil)
        }.to raise_error(UnauthorizedError, "Invalid refresh token")
      end
    end

    context "repeated logout" do
      it "can be safely repeated for an already-revoked token" do
        issued = issue_token(user: user)

        described_class.call(refresh_token: issued[:raw_token])
        expect { described_class.call(refresh_token: issued[:raw_token]) }.not_to raise_error
      end
    end
  end
end
