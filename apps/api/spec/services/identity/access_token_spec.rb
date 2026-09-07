# frozen_string_literal: true

require "rails_helper"

RSpec.describe Identity::AccessToken do
  let(:user) do
    User.create!(
      email: "ada@example.com",
      first_name: "Ada",
      last_name: "Lovelace",
      password: "secure_password"
    )
  end

  describe ".encode" do
    it "produces a JWT string" do
      token = described_class.encode(user)
      expect(token).to be_a(String)
      expect(token.split(".").length).to eq(3)
    end

    it "includes the user UUID as the sub claim" do
      token = described_class.encode(user)
      payload = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: "HS256").first
      expect(payload["sub"]).to eq(user.id)
    end

    it "includes an iat claim" do
      token = described_class.encode(user)
      payload = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: "HS256").first
      expect(payload["iat"]).to be_present
    end

    it "includes an exp claim" do
      token = described_class.encode(user)
      payload = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: "HS256").first
      expect(payload["exp"]).to be_present
    end

    it "sets expiration in the future" do
      token = described_class.encode(user)
      payload = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: "HS256").first
      expect(payload["exp"]).to be > Time.current.to_i
    end
  end

  describe ".decode" do
    it "returns the payload for a valid token" do
      token = described_class.encode(user)
      payload = described_class.decode(token)

      expect(payload[:sub]).to eq(user.id)
      expect(payload[:iat]).to be_present
      expect(payload[:exp]).to be_present
    end

    it "raises UnauthorizedError for an invalid signature" do
      token = described_class.encode(user)
      # Tamper with the token
      tampered = token[0..-5] + "xxxx"

      expect { described_class.decode(tampered) }.to raise_error(UnauthorizedError, "Invalid token")
    end

    it "raises UnauthorizedError for a malformed token" do
      expect { described_class.decode("not.a.valid.jwt") }.to raise_error(UnauthorizedError, "Invalid token")
    end

    it "raises UnauthorizedError for an expired token" do
      token = nil
      travel_to(2.hours.ago) { token = described_class.encode(user) }

      expect { described_class.decode(token) }.to raise_error(UnauthorizedError, "Token has expired")
    end

    it "raises UnauthorizedError when required claims are missing" do
      # Encode a token without the sub claim
      incomplete_payload = { iat: Time.current.to_i, exp: 1.hour.from_now.to_i }
      token = JWT.encode(incomplete_payload, Rails.application.secret_key_base, "HS256")

      expect { described_class.decode(token) }.to raise_error(UnauthorizedError, "Invalid token")
    end

    it "raises UnauthorizedError for an unsigned (alg: none) token" do
      payload = { sub: user.id, iat: Time.current.to_i, exp: 1.hour.from_now.to_i }
      token = JWT.encode(payload, nil, "none")

      expect { described_class.decode(token) }.to raise_error(UnauthorizedError, "Invalid token")
    end
  end
end
