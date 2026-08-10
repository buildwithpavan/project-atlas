# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /api/v1/auth/refresh", type: :request do
  let!(:user) do
    User.create!(
      email: "ada@example.com",
      first_name: "Ada",
      last_name: "Lovelace",
      password: "secure_password"
    )
  end

  def login
    post "/api/v1/auth/login", params: { email: "ada@example.com", password: "secure_password" }
    response.parsed_body["data"]
  end

  describe "successful refresh" do
    it "returns HTTP 200" do
      data = login
      post "/api/v1/auth/refresh", params: { refresh_token: data["refresh_token"] }
      expect(response).to have_http_status(:ok)
    end

    it "returns an access_token" do
      data = login
      post "/api/v1/auth/refresh", params: { refresh_token: data["refresh_token"] }
      expect(response.parsed_body["data"]["access_token"]).to be_present
    end

    it "returns a new refresh_token" do
      data = login
      old_refresh = data["refresh_token"]
      post "/api/v1/auth/refresh", params: { refresh_token: old_refresh }
      new_refresh = response.parsed_body["data"]["refresh_token"]

      expect(new_refresh).to be_present
      expect(new_refresh).not_to eq(old_refresh)
    end

    it "returns expires_in" do
      data = login
      post "/api/v1/auth/refresh", params: { refresh_token: data["refresh_token"] }
      expect(response.parsed_body["data"]["expires_in"]).to eq(3600)
    end

    it "does not expose token_digest in the response" do
      data = login
      post "/api/v1/auth/refresh", params: { refresh_token: data["refresh_token"] }
      expect(response.body).not_to include("token_digest")
    end

    it "does not expose password or password_digest in the response" do
      data = login
      post "/api/v1/auth/refresh", params: { refresh_token: data["refresh_token"] }
      expect(response.body).not_to include("password_digest")
      expect(response.body).not_to include("secure_password")
    end
  end

  describe "old refresh token after rotation" do
    it "returns HTTP 401" do
      data = login
      old_refresh = data["refresh_token"]

      # Rotate
      post "/api/v1/auth/refresh", params: { refresh_token: old_refresh }
      expect(response).to have_http_status(:ok)

      # Reuse old token
      post "/api/v1/auth/refresh", params: { refresh_token: old_refresh }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "reuse detection revokes family" do
    it "revokes the successor token when old token is reused" do
      data = login
      old_refresh = data["refresh_token"]

      # Rotate: old → new
      post "/api/v1/auth/refresh", params: { refresh_token: old_refresh }
      new_refresh = response.parsed_body["data"]["refresh_token"]

      # Reuse old token — triggers family revocation
      post "/api/v1/auth/refresh", params: { refresh_token: old_refresh }
      expect(response).to have_http_status(:unauthorized)

      # New token should also be revoked
      post "/api/v1/auth/refresh", params: { refresh_token: new_refresh }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "failed refresh" do
    it "returns HTTP 401 for expired token" do
      data = login
      RefreshToken.last.update!(expires_at: 1.day.ago)

      post "/api/v1/auth/refresh", params: { refresh_token: data["refresh_token"] }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns HTTP 401 for invalid token" do
      post "/api/v1/auth/refresh", params: { refresh_token: "invalid_token" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns HTTP 401 for missing token" do
      post "/api/v1/auth/refresh", params: {}
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns RFC 9457 Problem Details format" do
      post "/api/v1/auth/refresh", params: { refresh_token: "invalid" }
      body = response.parsed_body

      expect(body["type"]).to eq("/errors/unauthorized")
      expect(body["title"]).to eq("Unauthorized")
      expect(body["status"]).to eq(401)
    end
  end
end
