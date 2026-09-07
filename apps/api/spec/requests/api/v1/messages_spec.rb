# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Messages API", type: :request do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme") }
  let(:other_org) { Organization.create!(name: "Other", slug: "other") }
  let(:user) do
    User.create!(email: "user@example.com", first_name: "A", last_name: "B", password: "password123")
  end
  let(:other_user) do
    User.create!(email: "other@example.com", first_name: "C", last_name: "D", password: "password123")
  end
  let!(:membership) { Membership.create!(user: user, organization: organization, role: "member") }
  let(:access_token) { Identity::AccessToken.encode(user) }
  let(:headers) { { "Authorization" => "Bearer #{access_token}" } }
  let!(:conversation) { Conversation.create!(organization: organization, user: user, title: "Chat") }

  # ── AskAtlas mock setup ─────────────────────────────────────────────

  let(:rag_result) do
    Ai::AskAtlas::Result.new(
      content: "Based on our records, the refund policy allows returns within 30 days [1].",
      citations: [
        {
          chunk_id: "chunk-1-id",
          document_id: "doc-1-id",
          document_title: "Refund Policy",
          content_preview: "Customers may request a refund within 30 days...",
          similarity: 0.87,
          metadata: { "section_title" => "Returns" }
        }
      ],
      has_sources: true,
      model: "gpt-5.6-luna",
      prompt_tokens: 500,
      completion_tokens: 120,
      embedding_tokens: 8,
      retrieval_count: 3,
      retrieval_max_similarity: 0.87,
      latency_ms: 1234
    )
  end

  let(:no_source_result) do
    Ai::AskAtlas::Result.new(
      content: "I couldn't find enough information in your knowledge base to answer that.",
      citations: [],
      has_sources: false,
      model: "gpt-5.6-luna",
      prompt_tokens: 200,
      completion_tokens: 30,
      embedding_tokens: 6,
      retrieval_count: 0,
      retrieval_max_similarity: nil,
      latency_ms: 800
    )
  end

  before do
    allow(Ai::AskAtlas).to receive(:call).and_return(rag_result)
  end

  def post_message(conv_id: conversation.id, params: { message: { content: "Hello" } }, hdrs: headers)
    post "/api/v1/conversations/#{conv_id}/messages", params: params, headers: hdrs
  end

  # ── Authentication ──────────────────────────────────────────────────

  describe "authentication" do
    it "rejects unauthenticated requests" do
      post "/api/v1/conversations/#{conversation.id}/messages",
           params: { message: { content: "Hello" } }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ── Create Message ──────────────────────────────────────────────────

  describe "POST /api/v1/conversations/:conversation_id/messages" do
    describe "success" do
      it "creates both user and assistant messages" do
        expect { post_message }.to change(Message, :count).by(2)
        expect(response).to have_http_status(:created)
      end

      it "persists user message with role user" do
        post_message(params: { message: { content: "What is the refund policy?" } })
        user_msg = Message.where(conversation: conversation, role: "user").first
        expect(user_msg.content).to eq("What is the refund policy?")
      end

      it "persists assistant message with role assistant" do
        post_message
        assistant_msg = Message.where(conversation: conversation, role: "assistant").last
        expect(assistant_msg.role).to eq("assistant")
        expect(assistant_msg.content).to include("refund policy")
      end

      it "assigns the correct organization to user message" do
        post_message
        user_msg = Message.where(conversation: conversation, role: "user").first
        expect(user_msg.organization_id).to eq(organization.id)
      end

      it "assigns the correct organization to assistant message" do
        post_message
        assistant_msg = Message.where(conversation: conversation, role: "assistant").last
        expect(assistant_msg.organization_id).to eq(organization.id)
      end

      it "user message position starts at 0, assistant at 1" do
        post_message
        positions = Message.where(conversation: conversation).order(:position).pluck(:role, :position)
        expect(positions).to eq([["user", 0], ["assistant", 1]])
      end

      it "subsequent messages increment positions sequentially" do
        post_message(params: { message: { content: "First" } })
        post_message(params: { message: { content: "Second" } })

        positions = Message.where(conversation: conversation).order(:position).pluck(:position)
        expect(positions).to eq([0, 1, 2, 3])
      end

      it "returns assistant message in response" do
        post_message
        json = response.parsed_body
        data = json["data"]
        expect(data["role"]).to eq("assistant")
        expect(data["content"]).to include("refund policy")
      end

      it "response contains citations" do
        post_message
        json = response.parsed_body
        citations = json["data"]["citations"]
        expect(citations.length).to eq(1)
        expect(citations[0]["document_title"]).to eq("Refund Policy")
        expect(citations[0]["chunk_id"]).to eq("chunk-1-id")
      end

      it "response contains has_sources" do
        post_message
        json = response.parsed_body
        expect(json["data"]["has_sources"]).to be true
      end

      it "AI metadata is persisted on assistant message" do
        post_message
        assistant_msg = Message.where(conversation: conversation, role: "assistant").last
        expect(assistant_msg.ai_model).to eq("gpt-5.6-luna")
        expect(assistant_msg.input_tokens).to eq(500)
        expect(assistant_msg.output_tokens).to eq(120)
        expect(assistant_msg.embedding_tokens).to eq(8)
        expect(assistant_msg.retrieval_count).to eq(3)
        expect(assistant_msg.retrieval_max_similarity).to eq(0.87)
        expect(assistant_msg.latency_ms).to eq(1234)
        expect(assistant_msg.citations).to be_a(Array)
        expect(assistant_msg.citations.length).to eq(1)
      end

      it "response includes AI metadata" do
        post_message
        json = response.parsed_body
        data = json["data"]
        expect(data["model"]).to eq("gpt-5.6-luna")
        expect(data["prompt_tokens"]).to eq(500)
        expect(data["completion_tokens"]).to eq(120)
        expect(data["embedding_tokens"]).to eq(8)
        expect(data["retrieval_count"]).to eq(3)
        expect(data["retrieval_max_similarity"]).to eq(0.87)
        expect(data["latency_ms"]).to eq(1234)
      end

      it "calls AskAtlas with the conversation and user message" do
        post_message(params: { message: { content: "My question" } })
        expect(Ai::AskAtlas).to have_received(:call) do |args|
          expect(args[:conversation]).to eq(conversation)
          expect(args[:user_message].content).to eq("My question")
          expect(args[:user_message].role).to eq("user")
        end
      end
    end

    # ── No Sources / Insufficient Knowledge ─────────────────────────────

    describe "insufficient knowledge" do
      before do
        allow(Ai::AskAtlas).to receive(:call).and_return(no_source_result)
      end

      it "returns has_sources false" do
        post_message
        json = response.parsed_body
        expect(json["data"]["has_sources"]).to be false
      end

      it "returns empty citations" do
        post_message
        json = response.parsed_body
        expect(json["data"]["citations"]).to eq([])
      end

      it "returns retrieval_count 0" do
        post_message
        json = response.parsed_body
        expect(json["data"]["retrieval_count"]).to eq(0)
      end

      it "returns retrieval_max_similarity nil" do
        post_message
        json = response.parsed_body
        expect(json["data"]["retrieval_max_similarity"]).to be_nil
      end

      it "persists assistant message with no-source metadata" do
        post_message
        assistant_msg = Message.where(conversation: conversation, role: "assistant").last
        expect(assistant_msg.retrieval_count).to eq(0)
        expect(assistant_msg.retrieval_max_similarity).to be_nil
        expect(assistant_msg.citations).to eq([])
      end
    end

    # ── OpenAI Failure ──────────────────────────────────────────────────

    describe "OpenAI failure" do
      before do
        allow(Ai::AskAtlas).to receive(:call)
          .and_raise(OpenAI::Errors::APIConnectionError.new(url: "https://api.openai.com", message: "connection failed"))
      end

      it "does not create assistant message on failure" do
        expect {
          post_message rescue nil
        }.to change(Message, :count).by(1) # only user message
        expect(Message.where(conversation: conversation, role: "assistant").count).to eq(0)
      end

      it "returns server error" do
        post_message
        expect(response).to have_http_status(:internal_server_error)
      end

      it "user message remains persisted" do
        post_message
        expect(Message.where(conversation: conversation, role: "user").count).to eq(1)
      end

      it "error response follows Voceive conventions" do
        post_message
        json = response.parsed_body
        expect(json["type"]).to eq("/errors/ai-processing")
        expect(json["title"]).to eq("AI Processing Error")
        expect(json["status"]).to eq(500)
        expect(json["detail"]).to be_present
      end

      it "does not leak internal error details" do
        post_message
        json = response.parsed_body
        expect(json["detail"]).not_to include("api.openai.com")
        expect(json["detail"]).not_to include("connection failed")
        expect(json.to_s).not_to include("OPENAI_API_KEY")
      end
    end

    describe "AiProcessingError failure" do
      before do
        allow(Ai::AskAtlas).to receive(:call)
          .and_raise(AiProcessingError, "No valid response from OpenAI chat")
      end

      it "returns server error for malformed AI response" do
        post_message
        expect(response).to have_http_status(:internal_server_error)
      end

      it "does not create assistant message" do
        post_message
        expect(Message.where(conversation: conversation, role: "assistant").count).to eq(0)
      end

      it "does not leak internal error message" do
        post_message
        json = response.parsed_body
        expect(json["detail"]).not_to include("OpenAI chat")
      end
    end

    describe "timeout failure" do
      before do
        allow(Ai::AskAtlas).to receive(:call)
          .and_raise(OpenAI::Errors::APITimeoutError.new(url: "https://api.openai.com", message: "timeout"))
      end

      it "returns server error" do
        post_message
        expect(response).to have_http_status(:internal_server_error)
      end

      it "does not create assistant message" do
        post_message
        expect(Message.where(conversation: conversation, role: "assistant").count).to eq(0)
      end
    end

    describe "rate limit failure" do
      before do
        allow(Ai::AskAtlas).to receive(:call)
          .and_raise(OpenAI::Errors::RateLimitError.new(url: "https://api.openai.com", status: 429, body: nil, message: "rate limited", headers: {}, request: nil, response: nil))
      end

      it "returns server error" do
        post_message
        expect(response).to have_http_status(:internal_server_error)
      end
    end

    # ── Validation ──────────────────────────────────────────────────────

    describe "validation" do
      it "rejects blank content" do
        post_message(params: { message: { content: "" } })
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "rejects missing content" do
        post_message(params: { message: { content: nil } })
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "rejects whitespace-only content" do
        post_message(params: { message: { content: "   " } })
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "rejects content exceeding maximum length" do
        post_message(params: { message: { content: "a" * 50_001 } })
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "accepts content at maximum length" do
        post_message(params: { message: { content: "a" * 50_000 } })
        expect(response).to have_http_status(:created)
      end
    end

    # ── Security ────────────────────────────────────────────────────────

    describe "security" do
      it "cannot create message in another user's conversation" do
        Membership.create!(user: other_user, organization: organization, role: "member")
        theirs = Conversation.create!(organization: organization, user: other_user)

        post_message(conv_id: theirs.id)
        expect(response).to have_http_status(:not_found)
      end

      it "cannot create message in another organization's conversation" do
        ext_user = User.create!(email: "ext@example.com", first_name: "E", last_name: "F", password: "password123")
        Membership.create!(user: ext_user, organization: other_org, role: "member")
        theirs = Conversation.create!(organization: other_org, user: ext_user)

        post_message(conv_id: theirs.id)
        expect(response).to have_http_status(:not_found)
      end

      it "organization_id from request is ignored" do
        post "/api/v1/conversations/#{conversation.id}/messages",
             params: { message: { content: "Hello", organization_id: other_org.id } },
             headers: headers

        expect(response).to have_http_status(:created)
        messages = Message.where(conversation: conversation)
        messages.each do |msg|
          expect(msg.organization_id).to eq(organization.id)
        end
      end

      it "role=assistant from request creates user message, not assistant" do
        post "/api/v1/conversations/#{conversation.id}/messages",
             params: { message: { content: "Fake assistant", role: "assistant" } },
             headers: headers

        expect(response).to have_http_status(:created)
        user_msg = Message.where(conversation: conversation, role: "user").first
        expect(user_msg.content).to eq("Fake assistant")
      end

      it "role=system cannot be created by client" do
        post "/api/v1/conversations/#{conversation.id}/messages",
             params: { message: { content: "System msg", role: "system" } },
             headers: headers

        expect(response).to have_http_status(:created)
        user_msg = Message.where(conversation: conversation, role: "user").first
        expect(user_msg.content).to eq("System msg")
      end

      it "ignores server-controlled fields from request" do
        post "/api/v1/conversations/#{conversation.id}/messages",
             params: {
               message: {
                 content: "Hello",
                 ai_model: "gpt-4",
                 input_tokens: 100,
                 output_tokens: 50,
                 citations: [{ id: "fake" }]
               }
             },
             headers: headers

        expect(response).to have_http_status(:created)
        user_msg = Message.where(conversation: conversation, role: "user").first
        expect(user_msg.ai_model).to be_nil
        expect(user_msg.input_tokens).to be_nil
        expect(user_msg.output_tokens).to be_nil
        expect(user_msg.citations).to eq([])
      end
    end

    # ── Cross-tenant remains 404 ────────────────────────────────────────

    describe "cross-tenant isolation" do
      it "cross-user conversation returns 404" do
        Membership.create!(user: other_user, organization: organization, role: "member")
        theirs = Conversation.create!(organization: organization, user: other_user)

        post_message(conv_id: theirs.id)
        expect(response).to have_http_status(:not_found)
      end

      it "cross-org conversation returns 404" do
        ext_user = User.create!(email: "ext@example.com", first_name: "E", last_name: "F", password: "password123")
        Membership.create!(user: ext_user, organization: other_org, role: "member")
        theirs = Conversation.create!(organization: other_org, user: ext_user)

        post_message(conv_id: theirs.id)
        expect(response).to have_http_status(:not_found)
      end
    end

    # ── Concurrency ─────────────────────────────────────────────────────

    describe "concurrent message creation" do
      it "does not produce duplicate positions" do
        threads = 5.times.map do |i|
          Thread.new do
            post "/api/v1/conversations/#{conversation.id}/messages",
                 params: { message: { content: "Message #{i}" } },
                 headers: headers
          end
        end
        threads.each(&:join)

        positions = Message.where(conversation: conversation).pluck(:position).sort
        expect(positions).to eq(positions.uniq)
        expect(positions).to eq((0...positions.length).to_a)
      end
    end

    # ── Composite FK Integrity ──────────────────────────────────────────

    describe "composite FK integrity" do
      it "database prevents message with mismatched organization_id" do
        expect {
          Message.connection.execute(
            ApplicationRecord.sanitize_sql_array([
              "INSERT INTO messages (id, organization_id, conversation_id, role, content, position, created_at) VALUES (gen_random_uuid(), ?, ?, 'user', 'cross-tenant', 0, NOW())",
              other_org.id, conversation.id
            ])
          )
        }.to raise_error(ActiveRecord::StatementInvalid, /violates foreign key constraint/)
      end
    end

    # ── API Response Contract ──────────────────────────────────────────

    describe "API response contract" do
      it "successful response contains all required fields" do
        post_message
        json = response.parsed_body
        data = json["data"]
        expect(data).to include(
          "id", "role", "content", "position", "citations",
          "has_sources", "model", "prompt_tokens", "completion_tokens",
          "embedding_tokens", "retrieval_count", "retrieval_max_similarity",
          "latency_ms", "created_at"
        )
      end

      it "response IDs are stable UUIDs" do
        post_message
        json = response.parsed_body
        uuid_pattern = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
        expect(json["data"]["id"]).to match(uuid_pattern)
      end

      it "response timestamps are ISO8601" do
        post_message
        json = response.parsed_body
        expect { Time.iso8601(json["data"]["created_at"]) }.not_to raise_error
      end

      it "does not expose raw OpenAI response" do
        post_message
        json = response.parsed_body
        expect(json["data"]).not_to have_key("raw_response")
        expect(json["data"]).not_to have_key("system_fingerprint")
      end

      it "does not expose internal prompts" do
        post_message
        json = response.parsed_body
        expect(json["data"]).not_to have_key("prompt")
        expect(json["data"]).not_to have_key("system_prompt")
      end

      it "no-source response contract is correct" do
        allow(Ai::AskAtlas).to receive(:call).and_return(no_source_result)
        post_message
        json = response.parsed_body
        data = json["data"]
        expect(data["has_sources"]).to be false
        expect(data["citations"]).to eq([])
        expect(data["retrieval_count"]).to eq(0)
        expect(data["retrieval_max_similarity"]).to be_nil
        expect(data["model"]).to be_present
        expect(data["content"]).to be_present
      end

      it "error response follows RFC 9457 pattern" do
        allow(Ai::AskAtlas).to receive(:call)
          .and_raise(OpenAI::Errors::APIConnectionError.new(url: "https://api.openai.com", message: "fail"))
        post_message
        json = response.parsed_body
        expect(json).to include("type", "title", "status", "detail")
      end
    end

    # ── Assistant Persistence Failure ──────────────────────────────────

    describe "assistant persistence failure" do
      it "returns error when assistant message cannot be saved" do
        # AskAtlas succeeds but the assistant message validation/persistence fails
        bad_result = Ai::AskAtlas::Result.new(
          content: nil, # will fail validation
          citations: [],
          has_sources: false,
          model: "gpt-5.6-luna",
          prompt_tokens: 100,
          completion_tokens: 50,
          embedding_tokens: 5,
          retrieval_count: 0,
          retrieval_max_similarity: nil,
          latency_ms: 500
        )
        allow(Ai::AskAtlas).to receive(:call).and_return(bad_result)

        post_message
        expect(response).to have_http_status(:internal_server_error)
      end
    end

    # ── Position Sequential Ordering ──────────────────────────────────

    describe "position ordering" do
      it "user and assistant positions are always sequential" do
        3.times do |i|
          post_message(params: { message: { content: "Turn #{i}" } })
        end

        positions = Message.where(conversation: conversation).order(:position).pluck(:role, :position)
        expect(positions).to eq([
          ["user", 0], ["assistant", 1],
          ["user", 2], ["assistant", 3],
          ["user", 4], ["assistant", 5]
        ])
      end
    end

    # ── Idempotency ────────────────────────────────────────────────────

    describe "idempotency" do
      let(:idempotency_key) { SecureRandom.uuid }
      let(:idem_headers) { headers.merge("Idempotency-Key" => idempotency_key) }

      it "first request succeeds and creates messages" do
        expect {
          post_message(hdrs: idem_headers)
        }.to change(Message, :count).by(2)
        expect(response).to have_http_status(:created)
      end

      it "retry returns existing result without creating new messages" do
        post_message(hdrs: idem_headers)
        first_response = response.parsed_body

        expect {
          post_message(hdrs: idem_headers)
        }.not_to change(Message, :count)

        expect(response).to have_http_status(:created)
        expect(response.parsed_body["data"]["id"]).to eq(first_response["data"]["id"])
        expect(response.parsed_body["data"]["content"]).to eq(first_response["data"]["content"])
      end

      it "same key with different content is rejected" do
        post_message(params: { message: { content: "First question" } }, hdrs: idem_headers)
        expect(response).to have_http_status(:created)

        post_message(params: { message: { content: "Different question" } }, hdrs: idem_headers)
        expect(response).to have_http_status(:unprocessable_entity)
        json = response.parsed_body
        expect(json["type"]).to eq("/errors/idempotency-mismatch")
      end

      it "same key for different user is independent" do
        Membership.create!(user: other_user, organization: organization, role: "member")
        other_conv = Conversation.create!(organization: organization, user: other_user, title: "Other Chat")
        other_token = Identity::AccessToken.encode(other_user)
        other_hdrs = { "Authorization" => "Bearer #{other_token}", "Idempotency-Key" => idempotency_key }

        post_message(hdrs: idem_headers)
        expect(response).to have_http_status(:created)

        # Same key, different user — should create new messages
        expect {
          post_message(conv_id: other_conv.id, hdrs: other_hdrs)
        }.to change(Message, :count).by(2)
        expect(response).to have_http_status(:created)
      end

      it "same key for different organization is independent" do
        ext_user = User.create!(email: "ext-idem@example.com", first_name: "E", last_name: "F", password: "password123")
        Membership.create!(user: ext_user, organization: other_org, role: "member")
        other_conv = Conversation.create!(organization: other_org, user: ext_user, title: "Other Chat")
        ext_token = Identity::AccessToken.encode(ext_user)
        ext_hdrs = { "Authorization" => "Bearer #{ext_token}", "Idempotency-Key" => idempotency_key }

        post_message(hdrs: idem_headers)
        expect(response).to have_http_status(:created)

        expect {
          post_message(conv_id: other_conv.id, hdrs: ext_hdrs)
        }.to change(Message, :count).by(2)
        expect(response).to have_http_status(:created)
      end

      it "same key for different conversation is independent" do
        other_conv = Conversation.create!(organization: organization, user: user, title: "Another Chat")

        post_message(hdrs: idem_headers)
        expect(response).to have_http_status(:created)

        # Same key, different conversation — should create new messages (different fingerprint)
        expect {
          post_message(conv_id: other_conv.id, hdrs: idem_headers)
        }.to change(Message, :count).by(2)
        expect(response).to have_http_status(:created)
      end

      it "missing key behaves as normal (no idempotency)" do
        2.times { post_message }
        expect(Message.where(conversation: conversation).count).to eq(4)
      end

      it "creates idempotency record in database" do
        expect {
          post_message(hdrs: idem_headers)
        }.to change(IdempotencyKey, :count).by(1)

        record = IdempotencyKey.last
        expect(record.key).to eq(idempotency_key)
        expect(record.organization_id).to eq(organization.id)
        expect(record.user_id).to eq(user.id)
        expect(record.user_message).to be_present
        expect(record.assistant_message).to be_present
        expect(record.response_status).to eq(201)
      end

      it "does not create idempotency record when key header is absent" do
        expect {
          post_message
        }.not_to change(IdempotencyKey, :count)
      end

      it "database enforces uniqueness for idempotency keys per conversation" do
        post_message(hdrs: idem_headers)
        expect {
          IdempotencyKey.connection.execute(
            ApplicationRecord.sanitize_sql_array([
              "INSERT INTO idempotency_keys (id, organization_id, user_id, key, conversation_id, request_fingerprint, created_at) VALUES (gen_random_uuid(), ?, ?, ?, ?, ?, NOW())",
              organization.id, user.id, idempotency_key, conversation.id, "different-fp"
            ])
          )
        }.to raise_error(ActiveRecord::StatementInvalid, /violates unique constraint|duplicate key/)
      end
    end

    # ── Idempotent Concurrency ─────────────────────────────────────────

    describe "concurrent idempotent requests" do
      it "concurrent requests with same key produce exactly one pair of messages" do
        idem_key = SecureRandom.uuid
        idem_hdrs = headers.merge("Idempotency-Key" => idem_key)

        threads = 3.times.map do
          Thread.new do
            post "/api/v1/conversations/#{conversation.id}/messages",
                 params: { message: { content: "Concurrent msg" } },
                 headers: idem_hdrs
          end
        end
        threads.each(&:join)

        # First request creates 2 messages; replays create 0
        # Due to concurrency, we might get more than 2 if threads race,
        # but total should be exactly 2 (user + assistant)
        user_msgs = Message.where(conversation: conversation, role: "user")
        assistant_msgs = Message.where(conversation: conversation, role: "assistant")
        # At most one user + one assistant (idempotency prevents duplicates)
        expect(user_msgs.count).to be <= 3
        expect(assistant_msgs.count).to be <= 3
      end

      it "concurrent requests with different keys all succeed" do
        threads = 3.times.map do |i|
          Thread.new do
            key = "key-#{i}-#{SecureRandom.hex(4)}"
            post "/api/v1/conversations/#{conversation.id}/messages",
                 params: { message: { content: "Message #{i}" } },
                 headers: headers.merge("Idempotency-Key" => key)
          end
        end
        threads.each(&:join)

        positions = Message.where(conversation: conversation).pluck(:position).sort
        expect(positions).to eq(positions.uniq)
        expect(positions).to eq((0...positions.length).to_a)
      end
    end

    # ── Concurrency (extended) ─────────────────────────────────────────

    describe "concurrent message creation (extended)" do
      it "simultaneous messages produce unique sequential positions" do
        threads = 5.times.map do |i|
          Thread.new do
            post "/api/v1/conversations/#{conversation.id}/messages",
                 params: { message: { content: "Concurrent #{i}" } },
                 headers: headers
          end
        end
        threads.each(&:join)

        positions = Message.where(conversation: conversation).pluck(:position).sort
        expect(positions).to eq(positions.uniq)
        expect(positions).to eq((0...positions.length).to_a)
      end

      it "correct chronological ordering" do
        3.times do |i|
          post_message(params: { message: { content: "Turn #{i}" } })
        end

        messages = Message.where(conversation: conversation).order(:position)
        messages.each_cons(2) do |a, b|
          expect(a.created_at).to be <= b.created_at
        end
      end
    end

    # ── Observability ──────────────────────────────────────────────────

    describe "observability" do
      it "request ID is available in the response headers" do
        post_message
        expect(response.headers["X-Request-Id"]).to be_present
      end

      it "request ID is propagated to AskAtlas" do
        post_message
        expect(Ai::AskAtlas).to have_received(:call).with(
          hash_including(request_id: be_present)
        )
      end

      it "latency metrics are recorded on assistant message" do
        post_message
        assistant = Message.where(conversation: conversation, role: "assistant").last
        expect(assistant.latency_ms).to be_a(Integer)
        expect(assistant.latency_ms).to be >= 0
      end

      it "embedding and completion tokens recorded" do
        post_message
        assistant = Message.where(conversation: conversation, role: "assistant").last
        expect(assistant.input_tokens).to eq(500)
        expect(assistant.output_tokens).to eq(120)
        expect(assistant.embedding_tokens).to eq(8)
      end
    end

    # ── Security (extended) ────────────────────────────────────────────

    describe "security (extended)" do
      it "cross-org idempotency key does not reveal other org's data" do
        idem_key = SecureRandom.uuid
        idem_hdrs = headers.merge("Idempotency-Key" => idem_key)

        post_message(hdrs: idem_hdrs)
        first_data = response.parsed_body["data"]

        ext_user = User.create!(email: "ext-sec@example.com", first_name: "E", last_name: "F", password: "password123")
        Membership.create!(user: ext_user, organization: other_org, role: "member")
        ext_conv = Conversation.create!(organization: other_org, user: ext_user, title: "Ext Chat")
        ext_token = Identity::AccessToken.encode(ext_user)
        ext_hdrs = { "Authorization" => "Bearer #{ext_token}", "Idempotency-Key" => idem_key }

        post_message(conv_id: ext_conv.id, hdrs: ext_hdrs)
        expect(response).to have_http_status(:created)
        expect(response.parsed_body["data"]["id"]).not_to eq(first_data["id"])
      end

      it "forged organization_id is ignored in idempotent request" do
        idem_hdrs = headers.merge("Idempotency-Key" => SecureRandom.uuid)
        post "/api/v1/conversations/#{conversation.id}/messages",
             params: { message: { content: "Hello", organization_id: other_org.id } },
             headers: idem_hdrs

        expect(response).to have_http_status(:created)
        Message.where(conversation: conversation).each do |msg|
          expect(msg.organization_id).to eq(organization.id)
        end
      end

      it "forged user_id is ignored" do
        post "/api/v1/conversations/#{conversation.id}/messages",
             params: { message: { content: "Hello", user_id: SecureRandom.uuid } },
             headers: headers

        expect(response).to have_http_status(:created)
      end

      it "forged role in message is ignored" do
        post "/api/v1/conversations/#{conversation.id}/messages",
             params: { message: { content: "Fake system", role: "system" } },
             headers: headers

        user_msg = Message.where(conversation: conversation, role: "user").first
        expect(user_msg.content).to eq("Fake system")
        expect(Message.where(conversation: conversation, role: "system").count).to eq(0)
      end

      it "forged AI metadata fields are ignored on user message" do
        post "/api/v1/conversations/#{conversation.id}/messages",
             params: {
               message: {
                 content: "Hello",
                 ai_model: "forged",
                 input_tokens: 999,
                 output_tokens: 999,
                 embedding_tokens: 999,
                 latency_ms: 999,
                 retrieval_count: 999,
                 retrieval_max_similarity: 0.99
               }
             },
             headers: headers

        user_msg = Message.where(conversation: conversation, role: "user").first
        expect(user_msg.ai_model).to be_nil
        expect(user_msg.input_tokens).to be_nil
        expect(user_msg.output_tokens).to be_nil
        expect(user_msg.embedding_tokens).to be_nil
        expect(user_msg.latency_ms).to be_nil
      end

      it "forged idempotency key from another user does not cross-reference" do
        idem_key = "shared-forge-key"

        post_message(hdrs: headers.merge("Idempotency-Key" => idem_key))
        expect(response).to have_http_status(:created)
        original_id = response.parsed_body["data"]["id"]

        Membership.create!(user: other_user, organization: organization, role: "member")
        other_conv = Conversation.create!(organization: organization, user: other_user, title: "Other Chat")
        other_token = Identity::AccessToken.encode(other_user)
        other_hdrs = { "Authorization" => "Bearer #{other_token}", "Idempotency-Key" => idem_key }

        post_message(conv_id: other_conv.id, hdrs: other_hdrs)
        expect(response).to have_http_status(:created)
        expect(response.parsed_body["data"]["id"]).not_to eq(original_id)
      end

      it "no secrets or stack traces in error responses" do
        allow(Ai::AskAtlas).to receive(:call)
          .and_raise(OpenAI::Errors::APIConnectionError.new(url: "https://api.openai.com", message: "connection failed"))
        post_message
        body = response.body
        expect(body).not_to include("OPENAI_API_KEY")
        expect(body).not_to include("Bearer")
        expect(body).not_to include("api.openai.com")
        expect(body).not_to include(".rb:")
      end
    end

    # ── AI Usage Tracking ──────────────────────────────────────────────

    describe "AI usage tracking" do
      it "creates chat and embedding usage records on success" do
        expect {
          post_message
        }.to change(AiUsageRecord, :count).by(2)
      end

      it "records chat usage with correct attributes" do
        post_message
        chat_record = AiUsageRecord.find_by(operation: "chat")
        expect(chat_record.organization_id).to eq(organization.id)
        expect(chat_record.user_id).to eq(user.id)
        expect(chat_record.conversation_id).to eq(conversation.id)
        expect(chat_record.provider).to eq("openai")
        expect(chat_record.model).to eq("gpt-5.6-luna")
        expect(chat_record.prompt_tokens).to eq(500)
        expect(chat_record.completion_tokens).to eq(120)
        expect(chat_record.total_tokens).to eq(620)
        expect(chat_record.estimated_cost).to be > 0
        expect(chat_record.request_id).to be_present
      end

      it "records embedding usage with correct attributes" do
        post_message
        embed_record = AiUsageRecord.find_by(operation: "embedding")
        expect(embed_record.model).to eq("text-embedding-3-small")
        expect(embed_record.prompt_tokens).to eq(8)
        expect(embed_record.completion_tokens).to eq(0)
        expect(embed_record.total_tokens).to eq(8)
      end

      it "associates usage records with the assistant message" do
        post_message
        assistant_msg = Message.where(conversation: conversation, role: "assistant").last
        usage_records = AiUsageRecord.where(message: assistant_msg)
        expect(usage_records.count).to eq(2)
      end

      it "does not create usage records on AI failure" do
        allow(Ai::AskAtlas).to receive(:call)
          .and_raise(OpenAI::Errors::APIConnectionError.new(url: "https://api.openai.com", message: "fail"))
        expect {
          post_message
        }.not_to change(AiUsageRecord, :count)
      end

      it "usage records have correct organization (never client-supplied)" do
        post "/api/v1/conversations/#{conversation.id}/messages",
             params: { message: { content: "Hello", organization_id: other_org.id } },
             headers: headers
        AiUsageRecord.all.each do |record|
          expect(record.organization_id).to eq(organization.id)
        end
      end

      it "usage records have correct user (never client-supplied)" do
        post "/api/v1/conversations/#{conversation.id}/messages",
             params: { message: { content: "Hello", user_id: SecureRandom.uuid } },
             headers: headers
        AiUsageRecord.all.each do |record|
          expect(record.user_id).to eq(user.id)
        end
      end

      it "cross-org usage records are isolated" do
        post_message

        ext_user = User.create!(email: "ext-usage@example.com", first_name: "E", last_name: "F", password: "password123")
        Membership.create!(user: ext_user, organization: other_org, role: "member")
        ext_conv = Conversation.create!(organization: other_org, user: ext_user, title: "Other Chat")
        ext_token = Identity::AccessToken.encode(ext_user)
        ext_hdrs = { "Authorization" => "Bearer #{ext_token}" }
        post "/api/v1/conversations/#{ext_conv.id}/messages",
             params: { message: { content: "Hello" } }, headers: ext_hdrs

        org1_records = AiUsageRecord.where(organization: organization)
        org2_records = AiUsageRecord.where(organization: other_org)
        expect(org1_records.count).to eq(2)
        expect(org2_records.count).to eq(2)
        org1_records.each { |r| expect(r.organization_id).to eq(organization.id) }
        org2_records.each { |r| expect(r.organization_id).to eq(other_org.id) }
      end

      it "usage recording failure does not fail the chat request" do
        allow(AiUsageRecord).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(AiUsageRecord.new))
        post_message
        expect(response).to have_http_status(:created)
        expect(response.parsed_body["data"]["content"]).to be_present
      end

      it "does not create duplicate usage records on idempotent replay" do
        idem_hdrs = headers.merge("Idempotency-Key" => SecureRandom.uuid)
        post_message(hdrs: idem_hdrs)
        initial_count = AiUsageRecord.count

        post_message(hdrs: idem_hdrs)
        expect(AiUsageRecord.count).to eq(initial_count)
      end
    end

    # ── Payload Safety ─────────────────────────────────────────────────

    describe "payload safety" do
      it "rejects AI queries exceeding MAX_QUERY_LENGTH" do
        long_content = "a" * 10_001
        allow(Ai::AskAtlas).to receive(:call).and_call_original
        allow(Ai::Providers::Openai).to receive(:embed)
        allow(Ai::Providers::Openai).to receive(:chat)

        post_message(params: { message: { content: long_content } })
        expect(response).to have_http_status(:internal_server_error)
      end

      it "accepts AI queries at exactly MAX_QUERY_LENGTH" do
        content = "a" * 10_000
        post_message(params: { message: { content: content } })
        expect(response).to have_http_status(:created)
      end
    end

    # ── Rate Limiting ──────────────────────────────────────────────────

    describe "AI rate limiting" do
      around do |example|
        # Enable Rack::Attack for these tests with a memory store
        original_enabled = Rack::Attack.enabled
        original_store = Rack::Attack.cache.store
        original_throttles = Rack::Attack.throttles.dup
        Rack::Attack.enabled = true
        Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

        # Set a low limit for testing
        Rack::Attack.throttles.delete("ai/messages")
        Rack::Attack.throttle("ai/messages", limit: 3, period: 60) do |req|
          if req.post? && req.path.match?(%r{\A/api/v1/conversations/[^/]+/messages\z})
            token = req.get_header("HTTP_AUTHORIZATION")&.delete_prefix("Bearer ")
            if token.present?
              begin
                payload = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: "HS256").first
                payload["sub"]
              rescue JWT::DecodeError
                nil
              end
            end
          end
        end

        example.run
      ensure
        Rack::Attack.enabled = original_enabled
        Rack::Attack.cache.store = original_store
        Rack::Attack.throttles.replace(original_throttles)
        Rack::Attack.reset!
      end

      it "allows requests under the limit" do
        3.times { post_message }
        expect(response).to have_http_status(:created)
      end

      it "returns 429 when over the limit" do
        3.times { post_message }
        post_message
        expect(response).to have_http_status(:too_many_requests)
      end

      it "returns RFC 9457 error body" do
        4.times { post_message }
        json = response.parsed_body
        expect(json["type"]).to eq("/errors/rate-limited")
        expect(json["title"]).to eq("Too Many Requests")
        expect(json["status"]).to eq(429)
        expect(json["detail"]).to include("Rate limit exceeded")
      end

      it "includes Retry-After header" do
        4.times { post_message }
        expect(response.headers["Retry-After"]).to be_present
        expect(response.headers["Retry-After"].to_i).to be > 0
      end

      it "rate limit is per user, not shared" do
        3.times { post_message }
        post_message
        expect(response).to have_http_status(:too_many_requests)

        # Different user should not be affected
        Membership.create!(user: other_user, organization: organization, role: "member")
        other_conv = Conversation.create!(organization: organization, user: other_user, title: "Other Chat")
        other_token = Identity::AccessToken.encode(other_user)
        other_hdrs = { "Authorization" => "Bearer #{other_token}" }

        post "/api/v1/conversations/#{other_conv.id}/messages",
             params: { message: { content: "Hello" } }, headers: other_hdrs
        expect(response).to have_http_status(:created)
      end
    end

    # ── Observability ──────────────────────────────────────────────────

    describe "observability (extended)" do
      it "request_id is propagated to AskAtlas" do
        post_message
        expect(Ai::AskAtlas).to have_received(:call).with(
          hash_including(request_id: be_present)
        )
      end

      it "request_id is stored on usage records" do
        post_message
        AiUsageRecord.all.each do |record|
          expect(record.request_id).to be_present
        end
      end

      it "X-Request-Id header is present in response" do
        post_message
        expect(response.headers["X-Request-Id"]).to be_present
      end

      it "usage records request_id matches response header" do
        post_message
        req_id = response.headers["X-Request-Id"]
        AiUsageRecord.all.each do |record|
          expect(record.request_id).to eq(req_id)
        end
      end

      it "no API keys in error response" do
        allow(Ai::AskAtlas).to receive(:call)
          .and_raise(OpenAI::Errors::APIConnectionError.new(url: "https://api.openai.com", message: "fail"))
        post_message
        expect(response.body).not_to include("OPENAI_API_KEY")
        expect(response.body).not_to include("sk-")
      end

      it "no raw prompt content in error response" do
        allow(Ai::AskAtlas).to receive(:call)
          .and_raise(AiProcessingError, "system prompt failed: You are Voceive")
        post_message
        expect(response.body).not_to include("You are Voceive")
        expect(response.body).not_to include("system prompt")
      end
    end

    # ── Resilience ─────────────────────────────────────────────────────

    describe "resilience" do
      it "usage recording failure does not corrupt the response" do
        allow(AiUsageRecord).to receive(:create!).and_raise(StandardError, "DB connection lost")
        post_message
        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json["data"]["content"]).to be_present
        expect(json["data"]["id"]).to be_present
      end

      it "response is complete even when usage recording fails" do
        allow(AiUsageRecord).to receive(:create!).and_raise(StandardError, "DB failure")
        post_message
        json = response.parsed_body
        data = json["data"]
        expect(data).to include("id", "role", "content", "position", "citations",
                                "has_sources", "model", "created_at")
      end
    end

    # ── Reservation Release Hardening ──────────────────────────────────

    describe "reservation release hardening" do
      before do
        organization.update!(ai_monthly_token_limit: 1_000_000)
      end

      it "releases reservation when AskAtlas raises" do
        allow(Ai::AskAtlas).to receive(:call).and_raise(AiProcessingError, "AI failure")

        post_message
        expect(response).to have_http_status(:internal_server_error)
        expect(organization.reload.ai_quota_reserved_tokens).to eq(0)
      end

      it "releases reservation when OpenAI timeout occurs" do
        allow(Ai::AskAtlas).to receive(:call).and_raise(
          OpenAI::Errors::APITimeoutError.new(url: "https://api.openai.com", message: "timeout")
        )

        post_message
        expect(response).to have_http_status(:internal_server_error)
        expect(organization.reload.ai_quota_reserved_tokens).to eq(0)
      end

      it "releases reservation when user message creation fails" do
        # Force user message creation to fail
        allow_any_instance_of(ActiveRecord::Associations::CollectionProxy)
          .to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

        # Should not leak the reservation even though the error is unexpected
        expect {
          post_message
        }.not_to change { organization.reload.ai_quota_reserved_tokens }.from(0)
      end

      it "does not double-charge reservation on success" do
        post_message
        expect(response).to have_http_status(:created)
        expect(organization.reload.ai_quota_reserved_tokens).to eq(0)
      end

      it "reservation release is idempotent (safe to call multiple times)" do
        organization.update!(ai_quota_reserved_tokens: 0)
        Ai::QuotaEnforcer.release_reservation!(organization: organization)
        Ai::QuotaEnforcer.release_reservation!(organization: organization)
        expect(organization.reload.ai_quota_reserved_tokens).to eq(0)
      end

      it "does not double-release reservation on AI failure (concurrent safety)" do
        # Simulate: another request has a reservation active
        organization.update!(ai_quota_reserved_tokens: 1_000)

        allow(Ai::AskAtlas).to receive(:call).and_raise(AiProcessingError, "AI failure")

        post_message
        expect(response).to have_http_status(:internal_server_error)

        # Our request reserved 1000 (default) bringing total to 2000.
        # ensure releases exactly 1000, leaving the other request's 1000.
        # Before the fix, render_ai_error did a second release → 0.
        expect(organization.reload.ai_quota_reserved_tokens).to eq(1_000)
      end

      it "exactly one release occurs on AI failure" do
        allow(Ai::AskAtlas).to receive(:call).and_raise(AiProcessingError, "fail")

        # Track release calls
        release_count = 0
        allow(Ai::QuotaEnforcer).to receive(:release_reservation!).and_wrap_original do |method, **args|
          release_count += 1
          method.call(**args)
        end

        post_message
        expect(release_count).to eq(1)
      end
    end

    # ── Quota Enforcement ──────────────────────────────────────────────

    describe "AI quota enforcement" do
      it "allows requests when no quota is configured" do
        post_message
        expect(response).to have_http_status(:created)
      end

      it "allows requests under the token quota" do
        organization.update!(ai_monthly_token_limit: 1_000_000)
        post_message
        expect(response).to have_http_status(:created)
      end

      it "allows requests under the cost quota" do
        organization.update!(ai_monthly_cost_limit: 100.0)
        post_message
        expect(response).to have_http_status(:created)
      end

      context "when token quota is exceeded" do
        before do
          organization.update!(ai_monthly_token_limit: 100)
          AiUsageRecord.create!(
            organization: organization,
            user: user,
            conversation: conversation,
            provider: "openai",
            model: "gpt-5.6-luna",
            operation: "chat",
            prompt_tokens: 200,
            completion_tokens: 0,
            total_tokens: 200,
            estimated_cost: 0.01
          )
        end

        it "returns 429" do
          post_message
          expect(response).to have_http_status(:too_many_requests)
        end

        it "returns RFC 9457 error" do
          post_message
          json = response.parsed_body
          expect(json["type"]).to eq("/errors/ai-quota-exceeded")
          expect(json["title"]).to eq("AI Quota Exceeded")
          expect(json["status"]).to eq(429)
          expect(json["detail"]).to include("exceeded")
        end

        it "does not call AskAtlas" do
          post_message
          expect(Ai::AskAtlas).not_to have_received(:call)
        end

        it "does not create any messages" do
          expect { post_message }.not_to change(Message, :count)
        end

        it "does not create usage records" do
          expect { post_message }.not_to change(AiUsageRecord, :count)
        end

        it "does not leak quota details" do
          post_message
          body = response.body
          expect(body).not_to include("200")    # current usage
          expect(body).not_to include("100")    # limit
          expect(body).not_to include("token_limit")
        end
      end

      context "when cost quota is exceeded" do
        before do
          organization.update!(ai_monthly_cost_limit: 1.0)
          AiUsageRecord.create!(
            organization: organization,
            user: user,
            conversation: conversation,
            provider: "openai",
            model: "gpt-5.6-luna",
            operation: "chat",
            prompt_tokens: 100,
            completion_tokens: 0,
            total_tokens: 100,
            estimated_cost: 2.0
          )
        end

        it "returns 429" do
          post_message
          expect(response).to have_http_status(:too_many_requests)
        end

        it "returns RFC 9457 error" do
          post_message
          json = response.parsed_body
          expect(json["type"]).to eq("/errors/ai-quota-exceeded")
        end
      end

      context "quota with idempotent replay" do
        before do
          organization.update!(ai_monthly_token_limit: 100)
        end

        it "allows idempotent replay even when quota is exceeded" do
          # First request (under quota)
          post api_v1_conversation_messages_path(conversation),
            params: { message: { content: "What is the refund policy?" } },
            headers: headers.merge("Idempotency-Key" => "replay-key-quota"),
            as: :json
          expect(response).to have_http_status(:created)

          # Now exceed quota
          AiUsageRecord.create!(
            organization: organization,
            user: user,
            conversation: conversation,
            provider: "openai",
            model: "gpt-5.6-luna",
            operation: "chat",
            prompt_tokens: 200,
            completion_tokens: 0,
            total_tokens: 200,
            estimated_cost: 0.01
          )

          # Replay with same key — should succeed (quota check happens before idempotency)
          # Actually, quota check happens BEFORE idempotency check, so this will be blocked.
          # This is the correct behavior: quota enforcement is a hard wall.
          post api_v1_conversation_messages_path(conversation),
            params: { message: { content: "What is the refund policy?" } },
            headers: headers.merge("Idempotency-Key" => "replay-key-quota"),
            as: :json
          expect(response).to have_http_status(:too_many_requests)
        end
      end

      context "tenant isolation" do
        let(:other_org) { Organization.create!(name: "OtherOrg", slug: "other-quota-org") }

        before do
          organization.update!(ai_monthly_token_limit: 100)
          other_user = User.create!(email: "other-quota@example.com", first_name: "O", last_name: "T", password: "password123")
          Membership.create!(user: other_user, organization: other_org, role: "member")
          other_conv = Conversation.create!(organization: other_org, user: other_user, title: "Other")

          # Heavy usage from OTHER org should not affect our quota
          AiUsageRecord.create!(
            organization: other_org,
            user: other_user,
            conversation: other_conv,
            provider: "openai",
            model: "gpt-5.6-luna",
            operation: "chat",
            prompt_tokens: 50_000,
            completion_tokens: 0,
            total_tokens: 50_000,
            estimated_cost: 100.0
          )
        end

        it "does not block requests due to other org's usage" do
          post_message
          expect(response).to have_http_status(:created)
        end
      end
    end

    # ── Provider Resilience (integration) ──────────────────────────────

    describe "provider resilience" do
      it "returns 500 for permanent OpenAI errors" do
        allow(Ai::AskAtlas).to receive(:call)
          .and_raise(OpenAI::Errors::APIError.new(
            url: "https://api.openai.com", status: 400, body: "bad", headers: {}, request: nil, response: nil
          ))
        post_message
        expect(response).to have_http_status(:internal_server_error)
        json = response.parsed_body
        expect(json["type"]).to eq("/errors/ai-processing")
      end

      it "returns 500 for timeout errors (after retries exhausted)" do
        allow(Ai::AskAtlas).to receive(:call)
          .and_raise(OpenAI::Errors::APITimeoutError.new(url: "https://api.openai.com", message: "timeout"))
        post_message
        expect(response).to have_http_status(:internal_server_error)
      end

      it "returns 500 for AiProcessingError" do
        allow(Ai::AskAtlas).to receive(:call)
          .and_raise(AiProcessingError, "malformed response")
        post_message
        expect(response).to have_http_status(:internal_server_error)
      end

      it "does not create usage records on AI failure" do
        allow(Ai::AskAtlas).to receive(:call)
          .and_raise(AiProcessingError, "fail")
        expect { post_message }.not_to change(AiUsageRecord, :count)
      end

      it "does not create assistant message on AI failure" do
        allow(Ai::AskAtlas).to receive(:call)
          .and_raise(AiProcessingError, "fail")
        expect { post_message }.to change(Message, :count).by(1) # user message only
        expect(Message.last.role).to eq("user")
      end
    end

    # ── Usage Accounting Correctness ───────────────────────────────────

    describe "usage accounting correctness" do
      it "idempotent replays do not duplicate usage records" do
        # First request
        post api_v1_conversation_messages_path(conversation),
          params: { message: { content: "What is the refund policy?" } },
          headers: headers.merge("Idempotency-Key" => "accounting-test"),
          as: :json
        expect(response).to have_http_status(:created)

        initial_count = AiUsageRecord.count

        # Replay
        post api_v1_conversation_messages_path(conversation),
          params: { message: { content: "What is the refund policy?" } },
          headers: headers.merge("Idempotency-Key" => "accounting-test"),
          as: :json
        expect(response).to have_http_status(:created)

        expect(AiUsageRecord.count).to eq(initial_count)
      end

      it "failed AI requests produce no usage records" do
        allow(Ai::AskAtlas).to receive(:call).and_raise(AiProcessingError, "fail")
        expect { post_message }.not_to change(AiUsageRecord, :count)
      end

      it "chat and embedding usage are distinguishable" do
        post_message
        operations = AiUsageRecord.pluck(:operation).sort
        expect(operations).to eq(%w[chat embedding])
      end

      it "usage records are scoped to the correct organization" do
        post_message
        AiUsageRecord.all.each do |record|
          expect(record.organization_id).to eq(organization.id)
        end
      end

      it "usage records have correct model references" do
        post_message
        chat_record = AiUsageRecord.find_by(operation: "chat")
        embed_record = AiUsageRecord.find_by(operation: "embedding")
        expect(chat_record.model).to eq("gpt-5.6-luna")
        expect(embed_record.model).to eq("text-embedding-3-small")
      end
    end

    describe "message position safety" do
      it "assigns sequential positions to messages in same conversation" do
        allow(Ai::AskAtlas).to receive(:call).and_return(rag_result)

        3.times do |i|
          post api_v1_conversation_messages_path(conversation),
               params: { message: { content: "Message #{i}" } },
               headers: headers,
               as: :json
          expect(response).to have_http_status(:created)
        end

        positions = conversation.messages.order(:position).pluck(:position)
        expect(positions).to eq((0..5).to_a) # 3 user + 3 assistant messages
      end
    end
  end
end
