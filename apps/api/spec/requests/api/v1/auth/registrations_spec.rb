# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /api/v1/auth/register", type: :request do
  let(:valid_params) do
    {
      first_name: "Ada",
      last_name: "Lovelace",
      email: "ada@example.com",
      password: "secure_password",
      password_confirmation: "secure_password",
      organization_name: "Acme Inc"
    }
  end

  describe "successful registration" do
    subject(:request) { post "/api/v1/auth/register", params: valid_params }

    it "returns HTTP 201 Created" do
      request
      expect(response).to have_http_status(:created)
    end

    it "returns user information in the response" do
      request
      data = response.parsed_body["data"]

      expect(data["user"]).to include(
        "email" => "ada@example.com",
        "first_name" => "Ada",
        "last_name" => "Lovelace"
      )
      expect(data["user"]["id"]).to be_present
    end

    it "returns organization information in the response" do
      request
      data = response.parsed_body["data"]

      expect(data["organization"]).to include(
        "name" => "Acme Inc",
        "slug" => "acme-inc"
      )
      expect(data["organization"]["id"]).to be_present
    end

    it "does not expose password in the response" do
      request
      body = response.body

      expect(body).not_to include("password_digest")
      expect(body).not_to include("password_confirmation")
      expect(response.parsed_body["data"]["user"]).not_to have_key("password")
      expect(response.parsed_body["data"]["user"]).not_to have_key("password_digest")
      expect(response.parsed_body["data"]["user"]).not_to have_key("password_confirmation")
    end
  end

  describe "validation errors" do
    it "returns RFC 9457 Problem Details for invalid data" do
      post "/api/v1/auth/register", params: valid_params.merge(email: "")

      expect(response).to have_http_status(:unprocessable_content)
      body = response.parsed_body

      expect(body["type"]).to eq("/errors/validation")
      expect(body["title"]).to eq("Validation Error")
      expect(body["status"]).to eq(422)
      expect(body["detail"]).to be_present
      expect(body["errors"]).to be_present
    end

    it "returns error for duplicate email" do
      post "/api/v1/auth/register", params: valid_params
      post "/api/v1/auth/register", params: valid_params.merge(organization_name: "Other Org")

      expect(response).to have_http_status(:unprocessable_content)
      body = response.parsed_body
      expect(body["errors"]["email"]).to include("has already been taken")
    end

    it "returns error for password confirmation mismatch" do
      post "/api/v1/auth/register", params: valid_params.merge(password_confirmation: "wrong")

      expect(response).to have_http_status(:unprocessable_content)
      body = response.parsed_body
      expect(body["errors"]["password_confirmation"]).to be_present
    end

    it "does not expose password fields in error responses" do
      post "/api/v1/auth/register", params: valid_params.merge(email: "")

      body = response.body
      expect(body).not_to include("secure_password")
      expect(body).not_to include("password_digest")
    end
  end
end
