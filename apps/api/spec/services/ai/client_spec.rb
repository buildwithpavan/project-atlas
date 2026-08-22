# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::Client, type: :service do
  let(:base_url) { "http://test-ai:9000" }
  let(:client) { described_class.new(base_url: base_url, timeout: 5) }
  let(:path) { "/v1/analyze/ticket" }
  let(:payload) { { ticket_id: "t-1", subject: "Test", description: "Desc" } }

  let(:success_body) do
    {
      "ticket_id" => "t-1",
      "sentiment" => "neutral",
      "summary" => "Placeholder",
      "category" => "general",
      "confidence" => 0.0,
      "feature_request" => false,
      "bug_report" => false
    }
  end

  def stub_http(response_code: "200", response_body: success_body.to_json, &block)
    http_double = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http_double)

    response = Net::HTTPResponse.allocate
    allow(response).to receive(:code).and_return(response_code)
    allow(response).to receive(:body).and_return(response_body)
    allow(http_double).to receive(:request).and_return(response)

    yield http_double if block
    http_double
  end

  describe "#post" do
    context "successful request" do
      before { stub_http }

      it "returns parsed JSON response" do
        result = client.post(path, payload)
        expect(result).to eq(success_body)
      end

      it "sends a POST request with JSON content type" do
        http_double = stub_http
        client.post(path, payload)

        expect(http_double).to have_received(:request) do |request|
          expect(request).to be_a(Net::HTTP::Post)
          expect(request["Content-Type"]).to eq("application/json")
        end
      end

      it "sends JSON body" do
        http_double = stub_http
        client.post(path, payload)

        expect(http_double).to have_received(:request) do |request|
          body = JSON.parse(request.body)
          expect(body["ticket_id"]).to eq("t-1")
          expect(body["subject"]).to eq("Test")
        end
      end

      it "constructs the correct URI" do
        stub_http
        client.post(path, payload)

        expect(Net::HTTP).to have_received(:start).with(
          "test-ai", 9000,
          use_ssl: false,
          open_timeout: 5,
          read_timeout: 5
        )
      end
    end

    context "configuration" do
      it "uses default base URL from ENV" do
        stub_http
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("AI_SERVICE_URL", "http://ai:8000").and_return("http://custom:3000")
        allow(ENV).to receive(:fetch).with("AI_SERVICE_TIMEOUT", "10").and_return("15")

        default_client = described_class.new
        default_client.post(path, payload)

        expect(Net::HTTP).to have_received(:start).with(
          "custom", 3000,
          use_ssl: false,
          open_timeout: 15,
          read_timeout: 15
        )
      end

      it "uses configurable timeout" do
        stub_http
        custom_client = described_class.new(base_url: base_url, timeout: 30)
        custom_client.post(path, payload)

        expect(Net::HTTP).to have_received(:start).with(
          "test-ai", 9000,
          use_ssl: false,
          open_timeout: 30,
          read_timeout: 30
        )
      end
    end

    context "connection failure" do
      it "raises ConnectionError on ECONNREFUSED" do
        allow(Net::HTTP).to receive(:start).and_raise(Errno::ECONNREFUSED, "Connection refused")

        expect { client.post(path, payload) }
          .to raise_error(Ai::Client::ConnectionError, /AI service unavailable/)
      end

      it "raises ConnectionError on SocketError" do
        allow(Net::HTTP).to receive(:start).and_raise(SocketError, "getaddrinfo: Name does not resolve")

        expect { client.post(path, payload) }
          .to raise_error(Ai::Client::ConnectionError, /AI service unavailable/)
      end
    end

    context "timeout" do
      it "raises TimeoutError on Net::OpenTimeout" do
        allow(Net::HTTP).to receive(:start).and_raise(Net::OpenTimeout, "execution expired")

        expect { client.post(path, payload) }
          .to raise_error(Ai::Client::TimeoutError, /AI service timeout/)
      end

      it "raises TimeoutError on Net::ReadTimeout" do
        allow(Net::HTTP).to receive(:start).and_raise(Net::ReadTimeout, "Net::ReadTimeout")

        expect { client.post(path, payload) }
          .to raise_error(Ai::Client::TimeoutError, /AI service timeout/)
      end
    end

    context "HTTP errors" do
      it "raises HttpError on 4xx" do
        stub_http(response_code: "422", response_body: '{"detail":"invalid"}')

        expect { client.post(path, payload) }
          .to raise_error(Ai::Client::HttpError) { |e|
            expect(e.status).to eq(422)
            expect(e.message).to include("HTTP 422")
          }
      end

      it "raises HttpError on 5xx" do
        stub_http(response_code: "500", response_body: '{"detail":"internal"}')

        expect { client.post(path, payload) }
          .to raise_error(Ai::Client::HttpError) { |e|
            expect(e.status).to eq(500)
            expect(e.message).to include("HTTP 500")
          }
      end
    end

    context "invalid JSON" do
      it "raises InvalidResponseError on malformed JSON" do
        stub_http(response_code: "200", response_body: "not json at all")

        expect { client.post(path, payload) }
          .to raise_error(Ai::Client::InvalidResponseError, /invalid JSON/)
      end
    end

    context "error hierarchy" do
      it "all errors inherit from Ai::Client::Error" do
        expect(Ai::Client::ConnectionError).to be < Ai::Client::Error
        expect(Ai::Client::TimeoutError).to be < Ai::Client::Error
        expect(Ai::Client::HttpError).to be < Ai::Client::Error
        expect(Ai::Client::InvalidResponseError).to be < Ai::Client::Error
      end
    end
  end
end
