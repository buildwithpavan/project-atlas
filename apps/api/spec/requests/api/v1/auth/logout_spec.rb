# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /api/v1/auth/logout", type: :request do
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

  describe "successful logout" do
    it "returns HTTP 204 No Content" do
      data = login
      post "/api/v1/auth/logout", params: { refresh_token: data["refresh_token"] }

      expect(response).to have_http_status(:no_content)
    end

    it "returns no body" do
      data = login
      post "/api/v1/auth/logout", params: { refresh_token: data["refresh_token"] }

      expect(response.body).to be_empty
    end

    it "prevents refresh after logout" do
      data = login
      post "/api/v1/auth/logout", params: { refresh_token: data["refresh_token"] }

      post "/api/v1/auth/refresh", params: { refresh_token: data["refresh_token"] }
      expect(response).to have_http_status(:unauthorized)
    end

    it "revokes all tokens in the same family" do
      data = login
      old_refresh = data["refresh_token"]

      # Rotate to create a second token in the family
      post "/api/v1/auth/refresh", params: { refresh_token: old_refresh }
      new_refresh = response.parsed_body["data"]["refresh_token"]

      # Logout using the new token
      post "/api/v1/auth/logout", params: { refresh_token: new_refresh }
      expect(response).to have_http_status(:no_content)

      # The new token can no longer be used
      post "/api/v1/auth/refresh", params: { refresh_token: new_refresh }
      expect(response).to have_http_status(:unauthorized)
    end

    it "does not affect another user's session" do
      other_user = User.create!(
        email: "charles@example.com",
        first_name: "Charles",
        last_name: "Babbage",
        password: "secure_password"
      )

      data = login
      post "/api/v1/auth/login", params: { email: "charles@example.com", password: "secure_password" }
      other_data = response.parsed_body["data"]

      post "/api/v1/auth/logout", params: { refresh_token: data["refresh_token"] }
      expect(response).to have_http_status(:no_content)

      # Other user's refresh token still works
      post "/api/v1/auth/refresh", params: { refresh_token: other_data["refresh_token"] }
      expect(response).to have_http_status(:ok)
    end

    it "can be repeated safely" do
      data = login
      post "/api/v1/auth/logout", params: { refresh_token: data["refresh_token"] }
      expect(response).to have_http_status(:no_content)

      post "/api/v1/auth/logout", params: { refresh_token: data["refresh_token"] }
      expect(response).to have_http_status(:no_content)
    end
  end

  describe "failed logout" do
    it "returns HTTP 401 for unknown refresh token" do
      post "/api/v1/auth/logout", params: { refresh_token: "unknown_token" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns HTTP 401 for missing refresh token" do
      post "/api/v1/auth/logout", params: {}
      expect(response).to have_http_status(:unauthorized)
    end

    it "does not expose token_digest in the response" do
      data = login
      post "/api/v1/auth/logout", params: { refresh_token: data["refresh_token"] }
      expect(response.body).not_to include("token_digest")
    end

    it "does not expose family_id in the response" do
      data = login
      post "/api/v1/auth/logout", params: { refresh_token: data["refresh_token"] }
      expect(response.body).not_to include("family_id")
    end

    it "does not expose password or password_digest" do
      post "/api/v1/auth/logout", params: { refresh_token: "invalid" }
      expect(response.body).not_to include("password_digest")
      expect(response.body).not_to include("secure_password")
    end
  end
end
