# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::Providers::Openai, type: :service do
  let(:ticket) { instance_double(Ticket, subject: "Cannot login", description: "I keep getting a 403 error when trying to sign in.") }

  let(:parsed_result) do
    instance_double(
      Ai::Schemas::TicketAnalysis,
      sentiment: "negative",
      summary: "Customer cannot login due to 403 error",
      category: "technical_issue",
      confidence: 0.95,
      feature_request: false,
      bug_report: true,
      knowledge_gap: false
    )
  end

  let(:mock_content) do
    instance_double("ContentBlock", parsed: parsed_result)
  end

  let(:mock_output_item) do
    instance_double("OutputItem", content: [ mock_content ])
  end

  let(:mock_response) do
    instance_double("Response", output: [ mock_output_item ])
  end

  let(:mock_client) do
    instance_double(OpenAI::Client)
  end

  let(:mock_responses) do
    instance_double("Responses")
  end

  before do
    allow(OpenAI::Client).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:responses).and_return(mock_responses)
    allow(mock_responses).to receive(:create).and_return(mock_response)
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("OPENAI_API_KEY").and_return("test-api-key")
    allow(ENV).to receive(:fetch).with("OPENAI_MODEL", "gpt-5.6-luna").and_return("gpt-5.6-luna")
  end

  describe ".analyze" do
    it "returns the parsed result from OpenAI" do
      result = described_class.analyze(ticket: ticket)
      expect(result).to eq(parsed_result)
    end

    it "creates a client with the configured API key" do
      described_class.analyze(ticket: ticket)
      expect(OpenAI::Client).to have_received(:new).with(api_key: "test-api-key")
    end

    it "calls responses.create with the correct model" do
      described_class.analyze(ticket: ticket)
      expect(mock_responses).to have_received(:create).with(
        model: "gpt-5.6-luna",
        input: anything,
        text: Ai::Schemas::TicketAnalysis
      )
    end

    it "includes ticket subject and body in the input" do
      described_class.analyze(ticket: ticket)
      expect(mock_responses).to have_received(:create) do |args|
        user_message = args[:input].find { |m| m[:role] == :user }
        expect(user_message[:content]).to include("Cannot login")
        expect(user_message[:content]).to include("403 error")
      end
    end

    it "includes a system prompt in the input" do
      described_class.analyze(ticket: ticket)
      expect(mock_responses).to have_received(:create) do |args|
        system_message = args[:input].find { |m| m[:role] == :system }
        expect(system_message[:content]).to include("support ticket analyst")
      end
    end

    context "when OPENAI_API_KEY is not set" do
      before do
        allow(ENV).to receive(:fetch).with("OPENAI_API_KEY").and_call_original
        # Simulate the key not being in the environment
        stub_const("ENV", ENV.to_h.except("OPENAI_API_KEY"))
      end

      it "raises a KeyError" do
        allow(OpenAI::Client).to receive(:new).and_call_original
        expect { described_class.analyze(ticket: ticket) }.to raise_error(KeyError, /OPENAI_API_KEY/)
      end
    end

    context "when OPENAI_MODEL is configured" do
      before do
        allow(ENV).to receive(:fetch).with("OPENAI_MODEL", "gpt-5.6-luna").and_return("gpt-4o")
      end

      it "uses the configured model" do
        described_class.analyze(ticket: ticket)
        expect(mock_responses).to have_received(:create).with(
          model: "gpt-4o",
          input: anything,
          text: Ai::Schemas::TicketAnalysis
        )
      end
    end

    context "when the response contains a refusal" do
      let(:refusal_content) { OpenAI::Models::Responses::ResponseOutputRefusal.new(refusal: "I cannot analyze this") }
      let(:mock_output_item_with_refusal) do
        instance_double("OutputItem", content: [ refusal_content ])
      end
      let(:mock_response) do
        instance_double("Response", output: [ mock_output_item_with_refusal ])
      end

      it "raises an error" do
        expect { described_class.analyze(ticket: ticket) }.to raise_error(RuntimeError, /No valid response content/)
      end
    end

    context "when OpenAI returns an API error" do
      before do
        allow(mock_responses).to receive(:create).and_raise(
          OpenAI::Errors::APIConnectionError.new(url: "https://api.openai.com", message: "connection failed")
        )
      end

      it "propagates the error" do
        expect { described_class.analyze(ticket: ticket) }.to raise_error(OpenAI::Errors::APIConnectionError)
      end
    end
  end
end
