# frozen_string_literal: true

require "rails_helper"

RSpec.describe Authenticatable, type: :request do
  # Use an anonymous controller to test the concern without a production endpoint
  before(:all) do
    Rails.application.routes.draw do
      get "/up", to: "rails/health#show"

      namespace :api do
        namespace :v1 do
          get :health, to: "health#show"

          namespace :auth do
            post :register, to: "registrations#create"
          end
        end
      end

      get "/test/authenticated", to: "test_auth#show"
    end
  end

  after(:all) do
    Rails.application.reload_routes!
  end

  let(:user) do
    User.create!(
      email: "ada@example.com",
      first_name: "Ada",
      last_name: "Lovelace",
      password: "secure_password"
    )
  end

  # Define a temporary controller for testing
  controller_class = Class.new(ApplicationController) do
    include Authenticatable

    before_action :authenticate_user!

    def show
      render json: { user_id: current_user.id }
    end
  end

  before do
    stub_const("TestAuthController", controller_class)
  end

  describe "missing Authorization header" do
    it "returns unauthorized" do
      get "/test/authenticated"

      expect(response).to have_http_status(:unauthorized)
      body = response.parsed_body
      expect(body["type"]).to eq("/errors/unauthorized")
      expect(body["title"]).to eq("Unauthorized")
    end
  end

  describe "malformed Authorization header" do
    it "returns unauthorized for non-Bearer scheme" do
      get "/test/authenticated", headers: { "Authorization" => "Basic abc123" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns unauthorized for empty Bearer value" do
      get "/test/authenticated", headers: { "Authorization" => "Bearer " }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "invalid JWT" do
    it "returns unauthorized" do
      get "/test/authenticated", headers: { "Authorization" => "Bearer invalid.token.here" }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "expired JWT" do
    it "returns unauthorized" do
      token = nil
      travel_to(2.hours.ago) { token = Identity::AccessToken.encode(user) }

      get "/test/authenticated", headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:unauthorized)
      body = response.parsed_body
      expect(body["detail"]).to eq("Token has expired")
    end
  end

  describe "valid JWT" do
    it "resolves the correct user as current_user" do
      token = Identity::AccessToken.encode(user)

      get "/test/authenticated", headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["user_id"]).to eq(user.id)
    end
  end

  describe "JWT referencing a nonexistent user" do
    it "returns unauthorized" do
      token = Identity::AccessToken.encode(user)
      user.destroy!

      get "/test/authenticated", headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:unauthorized)
      body = response.parsed_body
      expect(body["detail"]).to eq("User not found")
    end
  end
end
