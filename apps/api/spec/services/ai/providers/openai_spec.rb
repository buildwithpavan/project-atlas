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

    it "creates a client with the configured API key and timeout" do
      described_class.analyze(ticket: ticket)
      expect(OpenAI::Client).to have_received(:new).with(
        api_key: "test-api-key",
        timeout: { connect: 5, read: 30 }
      )
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

  describe ".embed" do
    let(:mock_embeddings) { instance_double("Embeddings") }

    let(:embedding_data) do
      [
        instance_double("EmbeddingItem", index: 0, embedding: [0.1] * 1536),
        instance_double("EmbeddingItem", index: 1, embedding: [0.2] * 1536)
      ]
    end

    let(:mock_embedding_response) do
      instance_double("EmbeddingResponse", data: embedding_data)
    end

    before do
      allow(mock_client).to receive(:embeddings).and_return(mock_embeddings)
      allow(mock_embeddings).to receive(:create).and_return(mock_embedding_response)
    end

    it "returns embeddings for an array of texts" do
      result = described_class.embed(texts: ["hello", "world"])
      expect(result.length).to eq(2)
      expect(result[0].length).to eq(1536)
    end

    it "calls the embeddings API with correct parameters" do
      described_class.embed(texts: ["hello"], model: "text-embedding-3-small", dimensions: 1536)
      expect(mock_embeddings).to have_received(:create).with(
        model: "text-embedding-3-small",
        input: ["hello"],
        dimensions: 1536
      )
    end

    it "defaults to text-embedding-3-small with 1536 dimensions" do
      described_class.embed(texts: ["test"])
      expect(mock_embeddings).to have_received(:create).with(
        model: "text-embedding-3-small",
        input: ["test"],
        dimensions: 1536
      )
    end

    it "preserves input order using index sorting" do
      # Return data in reverse order to test sorting
      reversed_data = [
        instance_double("EmbeddingItem", index: 1, embedding: [0.2] * 1536),
        instance_double("EmbeddingItem", index: 0, embedding: [0.1] * 1536)
      ]
      reversed_response = instance_double("EmbeddingResponse", data: reversed_data)
      allow(mock_embeddings).to receive(:create).and_return(reversed_response)

      result = described_class.embed(texts: ["first", "second"])
      expect(result[0]).to eq([0.1] * 1536)
      expect(result[1]).to eq([0.2] * 1536)
    end

    context "when OpenAI returns an API error" do
      before do
        allow(mock_embeddings).to receive(:create).and_raise(
          OpenAI::Errors::APITimeoutError.new(url: "https://api.openai.com", message: "request timed out")
        )
      end

      it "propagates the error" do
        expect { described_class.embed(texts: ["hello"]) }.to raise_error(OpenAI::Errors::APITimeoutError)
      end
    end

    context "with include_usage: true" do
      let(:mock_usage) do
        instance_double("EmbeddingUsage", prompt_tokens: 12)
      end

      before do
        allow(mock_embedding_response).to receive(:usage).and_return(mock_usage)
      end

      it "returns a hash with vectors and usage" do
        result = described_class.embed(texts: ["hello"], include_usage: true)
        expect(result).to be_a(Hash)
        expect(result[:vectors]).to be_a(Array)
        expect(result[:usage][:prompt_tokens]).to eq(12)
      end

      it "vectors are in input order" do
        result = described_class.embed(texts: ["hello", "world"], include_usage: true)
        expect(result[:vectors].length).to eq(2)
      end
    end

    context "with include_usage: false (default)" do
      it "returns plain array of vectors" do
        result = described_class.embed(texts: ["hello"])
        expect(result).to be_a(Array)
        expect(result.first).to be_a(Array)
      end
    end
  end

  describe ".chat" do
    let(:mock_chat) { instance_double("Chat") }
    let(:mock_completions) { instance_double("Completions") }

    let(:mock_chat_usage) do
      instance_double("CompletionUsage", prompt_tokens: 500, completion_tokens: 120)
    end

    let(:mock_chat_message) do
      instance_double("ChatCompletionMessage", content: "Here is the answer.", role: "assistant")
    end

    let(:mock_choice) do
      instance_double("Choice", message: mock_chat_message)
    end

    let(:mock_chat_response) do
      instance_double("ChatCompletion",
        choices: [mock_choice],
        model: "gpt-5.6-luna",
        usage: mock_chat_usage
      )
    end

    before do
      allow(mock_client).to receive(:chat).and_return(mock_chat)
      allow(mock_chat).to receive(:completions).and_return(mock_completions)
      allow(mock_completions).to receive(:create).and_return(mock_chat_response)
    end

    it "passes messages to the chat completions API" do
      messages = [
        { role: "system", content: "You are helpful." },
        { role: "user", content: "Hello" }
      ]
      described_class.chat(messages: messages)
      expect(mock_completions).to have_received(:create).with(
        model: "gpt-5.6-luna",
        messages: messages
      )
    end

    it "uses the configured model" do
      allow(ENV).to receive(:fetch).with("OPENAI_MODEL", "gpt-5.6-luna").and_return("gpt-4o")
      described_class.chat(messages: [{ role: "user", content: "Hi" }])
      expect(mock_completions).to have_received(:create).with(
        hash_including(model: "gpt-4o")
      )
    end

    it "allows model override" do
      described_class.chat(messages: [{ role: "user", content: "Hi" }], model: "gpt-4o-mini")
      expect(mock_completions).to have_received(:create).with(
        hash_including(model: "gpt-4o-mini")
      )
    end

    it "returns the chat completion response" do
      result = described_class.chat(messages: [{ role: "user", content: "Hi" }])
      expect(result).to eq(mock_chat_response)
    end

    it "response contains usage data" do
      result = described_class.chat(messages: [{ role: "user", content: "Hi" }])
      expect(result.usage.prompt_tokens).to eq(500)
      expect(result.usage.completion_tokens).to eq(120)
    end

    it "response contains answer content" do
      result = described_class.chat(messages: [{ role: "user", content: "Hi" }])
      expect(result.choices.first.message.content).to eq("Here is the answer.")
    end

    context "when OpenAI returns an API error" do
      before do
        allow(mock_completions).to receive(:create)
          .and_raise(OpenAI::Errors::APIConnectionError.new(url: "https://api.openai.com", message: "connection failed"))
      end

      it "propagates the error" do
        expect {
          described_class.chat(messages: [{ role: "user", content: "Hi" }])
        }.to raise_error(OpenAI::Errors::APIConnectionError)
      end
    end

    context "when OpenAI returns a timeout" do
      before do
        allow(mock_completions).to receive(:create)
          .and_raise(OpenAI::Errors::APITimeoutError.new(url: "https://api.openai.com", message: "timeout"))
      end

      it "propagates the timeout error" do
        expect {
          described_class.chat(messages: [{ role: "user", content: "Hi" }])
        }.to raise_error(OpenAI::Errors::APITimeoutError)
      end
    end

    context "when OpenAI returns a rate limit error" do
      before do
        allow(mock_completions).to receive(:create)
          .and_raise(OpenAI::Errors::RateLimitError.new(url: "https://api.openai.com", status: 429, body: nil, message: "rate limited", headers: {}, request: nil, response: nil))
      end

      it "propagates the rate limit error" do
        expect {
          described_class.chat(messages: [{ role: "user", content: "Hi" }])
        }.to raise_error(OpenAI::Errors::RateLimitError)
      end
    end

    context "when OpenAI returns an internal server error" do
      before do
        allow(mock_completions).to receive(:create)
          .and_raise(OpenAI::Errors::InternalServerError.new(url: "https://api.openai.com", status: 500, body: nil, message: "internal", headers: {}, request: nil, response: nil))
      end

      it "propagates the internal server error" do
        expect {
          described_class.chat(messages: [{ role: "user", content: "Hi" }])
        }.to raise_error(OpenAI::Errors::InternalServerError)
      end
    end
  end

  # ── Timeout Configuration ──────────────────────────────────────────

  describe "timeout configuration" do
    let(:mock_chat) { instance_double("Chat") }
    let(:mock_completions) { instance_double("Completions") }
    let(:mock_chat_response) do
      instance_double("ChatCompletion",
        choices: [instance_double("Choice", message: instance_double("Msg", content: "Hi", role: "assistant"))],
        model: "gpt-5.6-luna",
        usage: instance_double("Usage", prompt_tokens: 10, completion_tokens: 5)
      )
    end
    let(:mock_embeddings) { instance_double("Embeddings") }
    let(:mock_embed_response) do
      instance_double("EmbeddingResponse",
        data: [instance_double("EmbeddingData", index: 0, embedding: [0.1] * 1536)],
        usage: instance_double("EmbedUsage", prompt_tokens: 5)
      )
    end

    before do
      allow(mock_client).to receive(:chat).and_return(mock_chat)
      allow(mock_chat).to receive(:completions).and_return(mock_completions)
      allow(mock_completions).to receive(:create).and_return(mock_chat_response)
      allow(mock_client).to receive(:embeddings).and_return(mock_embeddings)
      allow(mock_embeddings).to receive(:create).and_return(mock_embed_response)
    end

    it "uses default timeout values" do
      described_class.chat(messages: [{ role: "user", content: "Hi" }])
      expect(OpenAI::Client).to have_received(:new).with(
        hash_including(timeout: { connect: 5, read: 30 })
      )
    end

    it "uses ENV-configured connect timeout" do
      allow(ENV).to receive(:fetch).with("OPENAI_CONNECT_TIMEOUT", "5").and_return("10")
      described_class.chat(messages: [{ role: "user", content: "Hi" }])
      expect(OpenAI::Client).to have_received(:new).with(
        hash_including(timeout: hash_including(connect: 10))
      )
    end

    it "uses ENV-configured read timeout" do
      allow(ENV).to receive(:fetch).with("OPENAI_READ_TIMEOUT", "30").and_return("60")
      described_class.chat(messages: [{ role: "user", content: "Hi" }])
      expect(OpenAI::Client).to have_received(:new).with(
        hash_including(timeout: hash_including(read: 60))
      )
    end

    it "passes timeout to client for embed calls" do
      described_class.embed(texts: ["test"])
      expect(OpenAI::Client).to have_received(:new).with(
        hash_including(timeout: { connect: 5, read: 30 })
      )
    end
  end
end
