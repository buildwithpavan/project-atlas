# frozen_string_literal: true

require "rails_helper"

RSpec.describe Identity::Login, type: :service do
  let!(:user) do
    User.create!(
      email: "ada@example.com",
      first_name: "Ada",
      last_name: "Lovelace",
      password: "secure_password"
    )
  end

  describe ".call" do
    context "with valid credentials" do
      it "authenticates successfully" do
        result = described_class.call(email: "ada@example.com", password: "secure_password")
        expect(result[:access_token]).to be_present
      end

      it "returns an access token string" do
        result = described_class.call(email: "ada@example.com", password: "secure_password")
        expect(result[:access_token].split(".").length).to eq(3)
      end

      it "returns the expected expiration" do
        result = described_class.call(email: "ada@example.com", password: "secure_password")
        expect(result[:expires_in]).to eq(3600)
      end

      it "performs case-insensitive email lookup" do
        result = described_class.call(email: "ADA@EXAMPLE.COM", password: "secure_password")
        expect(result[:access_token]).to be_present
      end

      it "uses Identity::AccessToken for token generation" do
        expect(Identity::AccessToken).to receive(:encode).with(user).and_call_original
        described_class.call(email: "ada@example.com", password: "secure_password")
      end
    end

    context "with invalid credentials" do
      it "raises UnauthorizedError for unknown email" do
        expect {
          described_class.call(email: "unknown@example.com", password: "secure_password")
        }.to raise_error(UnauthorizedError, "Invalid email or password")
      end

      it "raises UnauthorizedError for incorrect password" do
        expect {
          described_class.call(email: "ada@example.com", password: "wrong_password")
        }.to raise_error(UnauthorizedError, "Invalid email or password")
      end

      it "raises UnauthorizedError for missing email" do
        expect {
          described_class.call(email: nil, password: "secure_password")
        }.to raise_error(UnauthorizedError, "Invalid email or password")
      end

      it "raises UnauthorizedError for missing password" do
        expect {
          described_class.call(email: "ada@example.com", password: nil)
        }.to raise_error(UnauthorizedError, "Invalid email or password")
      end

      it "returns the same error for unknown email and incorrect password" do
        unknown_error = begin
          described_class.call(email: "unknown@example.com", password: "secure_password")
        rescue UnauthorizedError => e
          e
        end

        wrong_pw_error = begin
          described_class.call(email: "ada@example.com", password: "wrong_password")
        rescue UnauthorizedError => e
          e
        end

        expect(unknown_error.detail).to eq(wrong_pw_error.detail)
        expect(unknown_error.status).to eq(wrong_pw_error.status)
        expect(unknown_error.type).to eq(wrong_pw_error.type)
      end
    end
  end
end
