# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Conversations API", type: :request do
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

  def create_conversation(org: organization, usr: user, title: nil)
    Conversation.create!(organization: org, user: usr, title: title)
  end

  def create_message(conversation:, position:, role: "user", content: "msg #{position}")
    Message.create!(
      organization: conversation.organization,
      conversation: conversation,
      role: role,
      content: content,
      position: position
    )
  end

  # ── POST /api/v1/conversations ──────────────────────────────────────

  describe "POST /api/v1/conversations" do
    describe "authentication" do
      it "rejects unauthenticated requests" do
        post "/api/v1/conversations", params: { conversation: { title: "Test" } }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe "authorization" do
      it "allows viewers to create conversations" do
        membership.update!(role: "viewer")
        post "/api/v1/conversations", params: { conversation: { title: "Test" } }, headers: headers
        expect(response).to have_http_status(:created)
      end

      it "allows members to create conversations" do
        post "/api/v1/conversations", params: { conversation: { title: "Test" } }, headers: headers
        expect(response).to have_http_status(:created)
      end

      it "allows admins to create conversations" do
        membership.update!(role: "admin")
        post "/api/v1/conversations", params: { conversation: { title: "Test" } }, headers: headers
        expect(response).to have_http_status(:created)
      end

      it "allows owners to create conversations" do
        membership.update!(role: "owner")
        post "/api/v1/conversations", params: { conversation: { title: "Test" } }, headers: headers
        expect(response).to have_http_status(:created)
      end
    end

    describe "success" do
      it "creates a conversation" do
        expect {
          post "/api/v1/conversations", params: { conversation: { title: "My Chat" } }, headers: headers
        }.to change(Conversation, :count).by(1)
      end

      it "assigns the correct organization" do
        post "/api/v1/conversations", params: { conversation: { title: "Test" } }, headers: headers
        conversation = Conversation.last
        expect(conversation.organization_id).to eq(organization.id)
      end

      it "assigns the correct user" do
        post "/api/v1/conversations", params: { conversation: { title: "Test" } }, headers: headers
        conversation = Conversation.last
        expect(conversation.user_id).to eq(user.id)
      end

      it "accepts optional title" do
        post "/api/v1/conversations", params: { conversation: { title: "Refund Question" } }, headers: headers
        json = response.parsed_body
        expect(json["data"]["title"]).to eq("Refund Question")
      end

      it "allows null title" do
        post "/api/v1/conversations", headers: headers
        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json["data"]["title"]).to be_nil
      end

      it "returns the conversation data" do
        post "/api/v1/conversations", params: { conversation: { title: "Test" } }, headers: headers
        json = response.parsed_body
        expect(json["data"]).to include("id", "title", "created_at", "updated_at")
      end

      it "does not call OpenAI" do
        expect(Ai::Providers::Openai).not_to receive(:embed)
        expect(Ai::Providers::Openai).not_to receive(:analyze)
        post "/api/v1/conversations", params: { conversation: { title: "Test" } }, headers: headers
      end
    end
  end

  # ── GET /api/v1/conversations ───────────────────────────────────────

  describe "GET /api/v1/conversations" do
    describe "authentication" do
      it "rejects unauthenticated requests" do
        get "/api/v1/conversations"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe "success" do
      it "returns only current user's conversations" do
        mine = create_conversation(title: "Mine")
        Membership.create!(user: other_user, organization: organization, role: "member")
        _theirs = create_conversation(usr: other_user, title: "Theirs")

        get "/api/v1/conversations", headers: headers
        json = response.parsed_body
        ids = json["data"].map { |c| c["id"] }
        expect(ids).to eq([mine.id])
      end

      it "returns newest first" do
        old = create_conversation(title: "Old")
        old.update!(created_at: 2.days.ago)
        recent = create_conversation(title: "Recent")

        get "/api/v1/conversations", headers: headers
        json = response.parsed_body
        ids = json["data"].map { |c| c["id"] }
        expect(ids).to eq([recent.id, old.id])
      end

      it "excludes other users in same org" do
        create_conversation(title: "Mine")
        Membership.create!(user: other_user, organization: organization, role: "member")
        create_conversation(usr: other_user, title: "Theirs")

        get "/api/v1/conversations", headers: headers
        json = response.parsed_body
        titles = json["data"].map { |c| c["title"] }
        expect(titles).to eq(["Mine"])
      end

      it "excludes other organizations" do
        create_conversation(title: "Mine")
        Membership.create!(user: other_user, organization: other_org, role: "member")
        create_conversation(org: other_org, usr: other_user, title: "Other Org")

        get "/api/v1/conversations", headers: headers
        json = response.parsed_body
        expect(json["data"].length).to eq(1)
      end

      it "returns empty array when no conversations" do
        get "/api/v1/conversations", headers: headers
        json = response.parsed_body
        expect(json["data"]).to eq([])
        expect(json["meta"]).to include("total" => 0, "total_pages" => 0)
      end

      it "does not include messages in index" do
        conv = create_conversation(title: "Chat")
        create_message(conversation: conv, position: 0)

        get "/api/v1/conversations", headers: headers
        json = response.parsed_body
        expect(json["data"].first).not_to have_key("messages")
      end

      it "returns pagination meta" do
        create_conversation(title: "Conv")

        get "/api/v1/conversations", headers: headers
        json = response.parsed_body
        expect(json["meta"]).to include(
          "page" => 1,
          "per_page" => 25,
          "total" => 1,
          "total_pages" => 1
        )
      end

      it "paginates results" do
        26.times { |i| create_conversation(title: "Conv #{i}") }

        get "/api/v1/conversations", headers: headers
        json = response.parsed_body
        expect(json["data"].length).to eq(25)
        expect(json["meta"]["total"]).to eq(26)
        expect(json["meta"]["total_pages"]).to eq(2)

        get "/api/v1/conversations", params: { page: 2 }, headers: headers
        json = response.parsed_body
        expect(json["data"].length).to eq(1)
        expect(json["meta"]["page"]).to eq(2)
      end

      it "respects per_page parameter" do
        3.times { |i| create_conversation(title: "Conv #{i}") }

        get "/api/v1/conversations", params: { per_page: 2 }, headers: headers
        json = response.parsed_body
        expect(json["data"].length).to eq(2)
        expect(json["meta"]["per_page"]).to eq(2)
        expect(json["meta"]["total_pages"]).to eq(2)
      end

      it "clamps per_page to maximum 100" do
        get "/api/v1/conversations", params: { per_page: 200 }, headers: headers
        json = response.parsed_body
        expect(json["meta"]["per_page"]).to eq(100)
      end
    end
  end

  # ── GET /api/v1/conversations/:id ──────────────────────────────────

  describe "GET /api/v1/conversations/:id" do
    describe "authentication" do
      it "rejects unauthenticated requests" do
        conv = create_conversation
        get "/api/v1/conversations/#{conv.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe "success" do
      it "returns own conversation" do
        conv = create_conversation(title: "My Chat")

        get "/api/v1/conversations/#{conv.id}", headers: headers
        json = response.parsed_body
        expect(json["data"]["id"]).to eq(conv.id)
        expect(json["data"]["title"]).to eq("My Chat")
      end

      it "includes messages" do
        conv = create_conversation
        create_message(conversation: conv, position: 0, content: "Hello")
        create_message(conversation: conv, position: 1, role: "assistant", content: "Hi there")

        get "/api/v1/conversations/#{conv.id}", headers: headers
        json = response.parsed_body
        expect(json["data"]["messages"].length).to eq(2)
      end

      it "messages ordered by position" do
        conv = create_conversation
        create_message(conversation: conv, position: 2, content: "Third")
        create_message(conversation: conv, position: 0, content: "First")
        create_message(conversation: conv, position: 1, content: "Second")

        get "/api/v1/conversations/#{conv.id}", headers: headers
        json = response.parsed_body
        positions = json["data"]["messages"].map { |m| m["position"] }
        expect(positions).to eq([0, 1, 2])
      end

      it "message fields include expected attributes" do
        conv = create_conversation
        msg = create_message(conversation: conv, position: 0, content: "Hello")

        get "/api/v1/conversations/#{conv.id}", headers: headers
        json = response.parsed_body
        message = json["data"]["messages"].first
        expect(message).to include("id", "role", "content", "position", "created_at")
        expect(message["id"]).to eq(msg.id)
        expect(message["role"]).to eq("user")
        expect(message["content"]).to eq("Hello")
        expect(message["position"]).to eq(0)
      end
    end

    describe "ownership isolation" do
      it "returns 404 for another user's conversation" do
        Membership.create!(user: other_user, organization: organization, role: "member")
        theirs = create_conversation(usr: other_user, title: "Theirs")

        get "/api/v1/conversations/#{theirs.id}", headers: headers
        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 for another organization's conversation" do
        other_user_in_other_org = User.create!(email: "ext@example.com", first_name: "E", last_name: "F", password: "password123")
        Membership.create!(user: other_user_in_other_org, organization: other_org, role: "member")
        theirs = create_conversation(org: other_org, usr: other_user_in_other_org)

        get "/api/v1/conversations/#{theirs.id}", headers: headers
        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 for non-existent conversation" do
        get "/api/v1/conversations/#{SecureRandom.uuid}", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ── DELETE /api/v1/conversations/:id ────────────────────────────────

  describe "DELETE /api/v1/conversations/:id" do
    describe "authentication" do
      it "rejects unauthenticated requests" do
        conv = create_conversation
        delete "/api/v1/conversations/#{conv.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe "authorization" do
      it "viewers cannot delete conversations" do
        membership.update!(role: "viewer")
        conv = create_conversation

        delete "/api/v1/conversations/#{conv.id}", headers: headers
        expect(response).to have_http_status(:forbidden)
      end

      it "members can delete own conversations" do
        conv = create_conversation
        delete "/api/v1/conversations/#{conv.id}", headers: headers
        expect(response).to have_http_status(:no_content)
      end

      it "admins can delete own conversations" do
        membership.update!(role: "admin")
        conv = create_conversation
        delete "/api/v1/conversations/#{conv.id}", headers: headers
        expect(response).to have_http_status(:no_content)
      end

      it "owners can delete own conversations" do
        membership.update!(role: "owner")
        conv = create_conversation
        delete "/api/v1/conversations/#{conv.id}", headers: headers
        expect(response).to have_http_status(:no_content)
      end
    end

    describe "success" do
      it "deletes the conversation" do
        conv = create_conversation
        expect {
          delete "/api/v1/conversations/#{conv.id}", headers: headers
        }.to change(Conversation, :count).by(-1)
      end

      it "returns no content" do
        conv = create_conversation
        delete "/api/v1/conversations/#{conv.id}", headers: headers
        expect(response).to have_http_status(:no_content)
      end

      it "cascade-deletes messages" do
        conv = create_conversation
        create_message(conversation: conv, position: 0)
        create_message(conversation: conv, position: 1)

        expect {
          delete "/api/v1/conversations/#{conv.id}", headers: headers
        }.to change(Message, :count).by(-2)
      end
    end

    describe "ownership isolation" do
      it "returns 404 for another user's conversation" do
        Membership.create!(user: other_user, organization: organization, role: "member")
        theirs = create_conversation(usr: other_user)

        delete "/api/v1/conversations/#{theirs.id}", headers: headers
        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 for another organization's conversation" do
        other_user_in_other_org = User.create!(email: "ext@example.com", first_name: "E", last_name: "F", password: "password123")
        Membership.create!(user: other_user_in_other_org, organization: other_org, role: "member")
        theirs = create_conversation(org: other_org, usr: other_user_in_other_org)

        delete "/api/v1/conversations/#{theirs.id}", headers: headers
        expect(response).to have_http_status(:not_found)
      end

      it "does not delete another user's conversation" do
        Membership.create!(user: other_user, organization: organization, role: "member")
        theirs = create_conversation(usr: other_user)

        expect {
          delete "/api/v1/conversations/#{theirs.id}", headers: headers
        }.not_to change(Conversation, :count)
      end
    end
  end
end
