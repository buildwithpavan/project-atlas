# frozen_string_literal: true

require "rails_helper"

RSpec.describe Identity::RefreshSession, type: :service do
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
      it "returns a new access token" do
        issued = issue_token(user: user)
        result = described_class.call(refresh_token: issued[:raw_token])
        expect(result[:access_token]).to be_present
        expect(result[:access_token].split(".").length).to eq(3)
      end

      it "returns a new refresh token" do
        issued = issue_token(user: user)
        result = described_class.call(refresh_token: issued[:raw_token])
        expect(result[:refresh_token]).to be_present
        expect(result[:refresh_token]).not_to eq(issued[:raw_token])
      end

      it "returns expires_in" do
        issued = issue_token(user: user)
        result = described_class.call(refresh_token: issued[:raw_token])
        expect(result[:expires_in]).to eq(3600)
      end

      it "makes the old refresh token unusable" do
        issued = issue_token(user: user)
        described_class.call(refresh_token: issued[:raw_token])

        expect {
          described_class.call(refresh_token: issued[:raw_token])
        }.to raise_error(UnauthorizedError)
      end

      it "preserves the same family_id" do
        issued = issue_token(user: user)
        old_family = issued[:record].family_id

        described_class.call(refresh_token: issued[:raw_token])

        new_token = RefreshToken.where(family_id: old_family, revoked_at: nil).last
        expect(new_token.family_id).to eq(old_family)
      end

      it "persists the replacement token" do
        issued = issue_token(user: user)
        expect {
          described_class.call(refresh_token: issued[:raw_token])
        }.to change(RefreshToken, :count).by(1)
      end

      it "links old token to the replacement" do
        issued = issue_token(user: user)
        described_class.call(refresh_token: issued[:raw_token])

        old_record = issued[:record].reload
        expect(old_record.replaced_by_token_id).to be_present
      end
    end

    context "with an expired refresh token" do
      it "raises UnauthorizedError" do
        issued = issue_token(user: user)
        issued[:record].update!(expires_at: 1.day.ago)

        expect {
          described_class.call(refresh_token: issued[:raw_token])
        }.to raise_error(UnauthorizedError, "Invalid refresh token")
      end
    end

    context "with a revoked refresh token" do
      it "raises UnauthorizedError" do
        issued = issue_token(user: user)
        issued[:record].revoke!

        expect {
          described_class.call(refresh_token: issued[:raw_token])
        }.to raise_error(UnauthorizedError, "Invalid refresh token")
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

    context "reuse detection" do
      it "detects reuse of a rotated token" do
        issued = issue_token(user: user)
        old_raw = issued[:raw_token]

        # First refresh succeeds and rotates
        described_class.call(refresh_token: old_raw)

        # Second use of the same token is reuse
        expect {
          described_class.call(refresh_token: old_raw)
        }.to raise_error(UnauthorizedError, "Invalid refresh token")
      end

      it "revokes the entire family on reuse" do
        issued = issue_token(user: user)
        old_raw = issued[:raw_token]
        family_id = issued[:record].family_id

        # Rotate once — creates Token B
        result_b = described_class.call(refresh_token: old_raw)

        # Reuse old token — triggers family revocation
        begin
          described_class.call(refresh_token: old_raw)
        rescue UnauthorizedError
          # expected
        end

        # Token B (the legitimate successor) should also be revoked
        expect {
          described_class.call(refresh_token: result_b[:refresh_token])
        }.to raise_error(UnauthorizedError, "Invalid refresh token")

        # All family tokens should be revoked
        active_in_family = RefreshToken.where(family_id: family_id, revoked_at: nil).count
        expect(active_in_family).to eq(0)
      end

      it "does not issue new tokens on reuse" do
        issued = issue_token(user: user)
        old_raw = issued[:raw_token]
        described_class.call(refresh_token: old_raw)

        count_before = RefreshToken.count
        begin
          described_class.call(refresh_token: old_raw)
        rescue UnauthorizedError
          # expected
        end
        expect(RefreshToken.count).to eq(count_before)
      end
    end

    context "transaction safety" do
      it "is transactional — rotation is atomic" do
        issued = issue_token(user: user)

        # Stub IssueRefreshToken to raise after the old token is found
        allow(Identity::IssueRefreshToken).to receive(:call).and_raise(ActiveRecord::RecordInvalid)

        expect {
          described_class.call(refresh_token: issued[:raw_token]) rescue nil
        }.not_to change(RefreshToken, :count)

        # Original token should remain unchanged (not revoked) since transaction rolled back
        expect(issued[:record].reload.revoked_at).to be_nil
      end
    end
  end
end
