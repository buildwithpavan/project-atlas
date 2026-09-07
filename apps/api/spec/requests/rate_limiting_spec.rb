# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Rate limiting", type: :request do
  around do |example|
    # Use a fresh MemoryStore for each test so throttle state is isolated.
    # MUST restore the original store (null_store in test env) afterward
    # to prevent leaking a functional MemoryStore into other specs.
    original_store = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.reset!
    example.run
  ensure
    Rack::Attack.cache.store = original_store
    Rack::Attack.reset!
  end

  describe "login throttling" do
    it "blocks after 5 attempts per minute" do
      5.times do
        post "/api/v1/auth/login", params: { email: "x@x.com", password: "wrong" }
      end

      post "/api/v1/auth/login", params: { email: "x@x.com", password: "wrong" }
      expect(response).to have_http_status(:too_many_requests)

      body = response.parsed_body
      expect(body["type"]).to eq("/errors/rate-limited")
      expect(body["status"]).to eq(429)
      expect(response.headers["Retry-After"]).to be_present
    end
  end

  describe "registration throttling" do
    it "blocks after 5 attempts per hour" do
      5.times do |i|
        post "/api/v1/auth/register", params: { email: "u#{i}@x.com", password: "pw" }
      end

      post "/api/v1/auth/register", params: { email: "u99@x.com", password: "pw" }
      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "RFC 9457 response format" do
    it "returns Problem Details JSON on 429" do
      6.times do
        post "/api/v1/auth/login", params: { email: "x@x.com", password: "wrong" }
      end

      body = response.parsed_body
      expect(body).to include("type", "title", "status", "detail")
      expect(response.content_type).to include("application/json")
    end
  end
end
