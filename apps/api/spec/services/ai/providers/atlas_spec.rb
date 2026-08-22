# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::Providers::Atlas, type: :service do
  let(:ticket) do
    instance_double(Ticket, id: "ticket-abc-123", subject: "Payment failed", description: "My payment was declined.")
  end

  let(:client_double) { instance_double(Ai::Client) }

  let(:fastapi_response) do
    {
      "ticket_id" => "ticket-abc-123",
      "sentiment" => "negative",
      "summary" => "Customer payment declined",
      "category" => "billing",
      "confidence" => 0.85,
      "feature_request" => false,
      "bug_report" => false
    }
  end

  before do
    allow(Ai::Client).to receive(:new).and_return(client_double)
    allow(client_double).to receive(:post).and_return(fastapi_response)
  end

  describe ".analyze" do
    it "sends the correct payload to FastAPI" do
      described_class.analyze(ticket: ticket)

      expect(client_double).to have_received(:post).with(
        "/v1/analyze/ticket",
        { ticket_id: "ticket-abc-123", subject: "Payment failed", description: "My payment was declined." }
      )
    end

    it "returns a result with sentiment" do
      result = described_class.analyze(ticket: ticket)
      expect(result.sentiment).to eq("negative")
    end

    it "returns a result with summary" do
      result = described_class.analyze(ticket: ticket)
      expect(result.summary).to eq("Customer payment declined")
    end

    it "returns a result with category" do
      result = described_class.analyze(ticket: ticket)
      expect(result.category).to eq("billing")
    end

    it "returns a result with confidence as float" do
      result = described_class.analyze(ticket: ticket)
      expect(result.confidence).to eq(0.85)
      expect(result.confidence).to be_a(Float)
    end

    it "returns a result with feature_request boolean" do
      result = described_class.analyze(ticket: ticket)
      expect(result.feature_request).to be(false)
    end

    it "returns a result with bug_report boolean" do
      result = described_class.analyze(ticket: ticket)
      expect(result.bug_report).to be(false)
    end

    it "defaults knowledge_gap to false when absent in response" do
      result = described_class.analyze(ticket: ticket)
      expect(result.knowledge_gap).to be(false)
    end

    it "maps knowledge_gap when present in response" do
      allow(client_double).to receive(:post).and_return(fastapi_response.merge("knowledge_gap" => true))
      result = described_class.analyze(ticket: ticket)
      expect(result.knowledge_gap).to be(true)
    end

    it "result interface is compatible with Ai::AnalyzeTicket expectations" do
      result = described_class.analyze(ticket: ticket)

      expect(result).to respond_to(:sentiment)
      expect(result).to respond_to(:summary)
      expect(result).to respond_to(:category)
      expect(result).to respond_to(:confidence)
      expect(result).to respond_to(:feature_request)
      expect(result).to respond_to(:bug_report)
      expect(result).to respond_to(:knowledge_gap)
    end

    it "propagates Ai::Client::ConnectionError" do
      allow(client_double).to receive(:post).and_raise(Ai::Client::ConnectionError, "unavailable")

      expect { described_class.analyze(ticket: ticket) }
        .to raise_error(Ai::Client::ConnectionError)
    end

    it "propagates Ai::Client::TimeoutError" do
      allow(client_double).to receive(:post).and_raise(Ai::Client::TimeoutError, "timed out")

      expect { described_class.analyze(ticket: ticket) }
        .to raise_error(Ai::Client::TimeoutError)
    end

    it "propagates Ai::Client::HttpError" do
      allow(client_double).to receive(:post).and_raise(Ai::Client::HttpError.new("HTTP 500", status: 500))

      expect { described_class.analyze(ticket: ticket) }
        .to raise_error(Ai::Client::HttpError)
    end
  end
end
