# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /api/v1/auth/login", type: :request do
  let!(:user) do
    User.create!(
      email: "ada@example.com",
      first_name: "Ada",
      last_name: "Lovelace",
      password: "secure_password"
    )
  end

  describe "successful login" do
    subject(:request) { post "/api/v1/auth/login", params: { email: "ada@example.com", password: "secure_password" } }

    it "returns HTTP 200" do
      request
      expect(response).to have_http_status(:ok)
    end

    it "returns an access_token in data" do
      request
      data = response.parsed_body["data"]
      expect(data["access_token"]).to be_present
      expect(data["access_token"].split(".").length).to eq(3)
    end

    it "returns expires_in = 3600" do
      request
      data = response.parsed_body["data"]
      expect(data["expires_in"]).to eq(3600)
    end

    it "does not expose password in the response" do
      request
      body = response.body
      expect(body).not_to include("password_digest")
      expect(body).not_to include("secure_password")
      expect(response.parsed_body["data"]).not_to have_key("password")
      expect(response.parsed_body["data"]).not_to have_key("password_digest")
    end

    it "supports case-insensitive email login" do
      post "/api/v1/auth/login", params: { email: "ADA@EXAMPLE.COM", password: "secure_password" }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"]["access_token"]).to be_present
    end
  end

  describe "failed login" do
    it "returns HTTP 401 for invalid password" do
      post "/api/v1/auth/login", params: { email: "ada@example.com", password: "wrong_password" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns HTTP 401 for unknown email" do
      post "/api/v1/auth/login", params: { email: "unknown@example.com", password: "secure_password" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns the same error structure for unknown email and wrong password" do
      post "/api/v1/auth/login", params: { email: "unknown@example.com", password: "secure_password" }
      unknown_body = response.parsed_body

      post "/api/v1/auth/login", params: { email: "ada@example.com", password: "wrong_password" }
      wrong_pw_body = response.parsed_body

      expect(unknown_body["type"]).to eq(wrong_pw_body["type"])
      expect(unknown_body["title"]).to eq(wrong_pw_body["title"])
      expect(unknown_body["detail"]).to eq(wrong_pw_body["detail"])
      expect(unknown_body["status"]).to eq(wrong_pw_body["status"])
    end

    it "returns RFC 9457 Problem Details format" do
      post "/api/v1/auth/login", params: { email: "ada@example.com", password: "wrong_password" }
      body = response.parsed_body

      expect(body["type"]).to eq("/errors/unauthorized")
      expect(body["title"]).to eq("Unauthorized")
      expect(body["status"]).to eq(401)
      expect(body["detail"]).to eq("Invalid email or password")
    end

    it "returns HTTP 401 for missing credentials" do
      post "/api/v1/auth/login", params: {}
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
