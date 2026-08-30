# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::Providers::Openai, "resilience", type: :service do
  describe ".retryable_error?" do
    it "classifies APITimeoutError as retryable" do
      error = OpenAI::Errors::APITimeoutError.new(url: "https://api.openai.com", message: "timeout")
      expect(described_class.retryable_error?(error)).to be true
    end

    it "classifies APIConnectionError as retryable" do
      error = OpenAI::Errors::APIConnectionError.new(url: "https://api.openai.com", message: "connection failed")
      expect(described_class.retryable_error?(error)).to be true
    end

    it "classifies RateLimitError as retryable" do
      error = OpenAI::Errors::RateLimitError.new(
        url: "https://api.openai.com",
        status: 429,
        body: "rate limited",
        headers: {},
        request: nil,
        response: nil
      )
      expect(described_class.retryable_error?(error)).to be true
    end

    it "classifies InternalServerError as retryable" do
      error = OpenAI::Errors::InternalServerError.new(
        url: "https://api.openai.com",
        status: 500,
        body: "internal server error",
        headers: {},
        request: nil,
        response: nil
      )
      expect(described_class.retryable_error?(error)).to be true
    end

    it "classifies generic APIError as NOT retryable" do
      error = OpenAI::Errors::APIError.new(
        url: "https://api.openai.com",
        status: 400,
        body: "bad request",
        headers: {},
        request: nil,
        response: nil
      )
      expect(described_class.retryable_error?(error)).to be false
    end

    it "classifies non-API errors as NOT retryable" do
      error = StandardError.new("something else")
      expect(described_class.retryable_error?(error)).to be false
    end
  end

  describe ".chat retry behavior" do
    let(:mock_client) { instance_double("OpenAI::Client") }
    let(:mock_chat) { instance_double("OpenAI::Resources::Chat") }
    let(:mock_completions) { instance_double("OpenAI::Resources::Chat::Completions") }
    let(:chat_response) do
      double("ChatCompletion",
        choices: [double("Choice", message: double("Message", content: "Hello"))],
        model: "gpt-5.6-luna",
        usage: double("Usage", prompt_tokens: 10, completion_tokens: 5)
      )
    end

    before do
      allow(OpenAI::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:chat).and_return(mock_chat)
      allow(mock_chat).to receive(:completions).and_return(mock_completions)
      # Disable sleep during tests
      allow(described_class).to receive(:sleep)
    end

    it "returns on first success without retrying" do
      allow(mock_completions).to receive(:create).and_return(chat_response)

      result = described_class.chat(messages: [{ role: "user", content: "hi" }])
      expect(result).to eq(chat_response)
      expect(mock_completions).to have_received(:create).once
    end

    it "retries on transient timeout and succeeds" do
      call_count = 0
      allow(mock_completions).to receive(:create) do
        call_count += 1
        if call_count == 1
          raise OpenAI::Errors::APITimeoutError.new(url: "https://api.openai.com", message: "timeout")
        end
        chat_response
      end

      result = described_class.chat(messages: [{ role: "user", content: "hi" }])
      expect(result).to eq(chat_response)
      expect(call_count).to eq(2)
    end

    it "retries on connection error and succeeds" do
      call_count = 0
      allow(mock_completions).to receive(:create) do
        call_count += 1
        if call_count == 1
          raise OpenAI::Errors::APIConnectionError.new(url: "https://api.openai.com", message: "connection failed")
        end
        chat_response
      end

      result = described_class.chat(messages: [{ role: "user", content: "hi" }])
      expect(result).to eq(chat_response)
      expect(call_count).to eq(2)
    end

    it "exhausts retries and raises on persistent timeout" do
      allow(mock_completions).to receive(:create)
        .and_raise(OpenAI::Errors::APITimeoutError.new(url: "https://api.openai.com", message: "timeout"))

      expect {
        described_class.chat(messages: [{ role: "user", content: "hi" }])
      }.to raise_error(OpenAI::Errors::APITimeoutError)

      # Initial attempt + MAX_RETRIES (default 2) = 3 total
      expect(mock_completions).to have_received(:create).exactly(3).times
    end

    it "does NOT retry permanent errors (400)" do
      allow(mock_completions).to receive(:create)
        .and_raise(OpenAI::Errors::APIError.new(
          url: "https://api.openai.com", status: 400, body: "bad", headers: {}, request: nil, response: nil
        ))

      expect {
        described_class.chat(messages: [{ role: "user", content: "hi" }])
      }.to raise_error(OpenAI::Errors::APIError)

      expect(mock_completions).to have_received(:create).once
    end

    it "logs retry warnings" do
      call_count = 0
      allow(mock_completions).to receive(:create) do
        call_count += 1
        if call_count == 1
          raise OpenAI::Errors::APITimeoutError.new(url: "https://api.openai.com", message: "timeout")
        end
        chat_response
      end
      allow(Rails.logger).to receive(:warn)

      described_class.chat(messages: [{ role: "user", content: "hi" }])

      expect(Rails.logger).to have_received(:warn).with(/\[OpenAI\] Retryable error.*attempt 1/)
    end
  end

  describe ".embed retry behavior" do
    let(:mock_client) { instance_double("OpenAI::Client") }
    let(:mock_embeddings) { instance_double("Embeddings") }
    let(:embed_response) do
      double("EmbeddingResponse",
        data: [double("EmbeddingItem", index: 0, embedding: [0.1] * 1536)],
        usage: double("EmbeddingUsage", prompt_tokens: 8)
      )
    end

    before do
      allow(OpenAI::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:embeddings).and_return(mock_embeddings)
      allow(described_class).to receive(:sleep)
    end

    it "returns on first success without retrying" do
      allow(mock_embeddings).to receive(:create).and_return(embed_response)

      result = described_class.embed(texts: ["hello"], include_usage: true)
      expect(result[:vectors].length).to eq(1)
      expect(mock_embeddings).to have_received(:create).once
    end

    it "retries on transient timeout and succeeds" do
      call_count = 0
      allow(mock_embeddings).to receive(:create) do
        call_count += 1
        if call_count == 1
          raise OpenAI::Errors::APITimeoutError.new(url: "https://api.openai.com", message: "timeout")
        end
        embed_response
      end

      result = described_class.embed(texts: ["hello"], include_usage: true)
      expect(result[:vectors].length).to eq(1)
      expect(call_count).to eq(2)
    end

    it "exhausts retries and raises on persistent timeout" do
      allow(mock_embeddings).to receive(:create)
        .and_raise(OpenAI::Errors::APITimeoutError.new(url: "https://api.openai.com", message: "timeout"))

      expect {
        described_class.embed(texts: ["hello"])
      }.to raise_error(OpenAI::Errors::APITimeoutError)

      expect(mock_embeddings).to have_received(:create).exactly(3).times
    end

    it "does NOT retry permanent errors" do
      allow(mock_embeddings).to receive(:create)
        .and_raise(OpenAI::Errors::APIError.new(
          url: "https://api.openai.com", status: 400, body: "bad", headers: {}, request: nil, response: nil
        ))

      expect {
        described_class.embed(texts: ["hello"])
      }.to raise_error(OpenAI::Errors::APIError)

      expect(mock_embeddings).to have_received(:create).once
    end
  end
end
