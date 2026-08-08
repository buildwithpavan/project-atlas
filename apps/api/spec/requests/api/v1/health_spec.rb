# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GET /api/v1/health", type: :request do
  describe "GET /api/v1/health" do
    subject(:request) { get "/api/v1/health" }

    it "returns a successful response" do
      request

      expect(response).to have_http_status(:ok)
    end

    it "returns the API health information" do
      request

      body = response.parsed_body

      expect(body).to include(
        "service" => "atlas-api",
        "version" => "v1"
      )
    end

    it "returns an ISO 8601 timestamp" do
      request

      timestamp = response.parsed_body.fetch("timestamp")

      expect { Time.iso8601(timestamp) }.not_to raise_error
    end
  end
end
