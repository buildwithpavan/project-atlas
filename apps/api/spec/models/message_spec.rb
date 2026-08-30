# frozen_string_literal: true

require "rails_helper"

RSpec.describe Message, type: :model do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme") }
  let(:user) { User.create!(email: "user@example.com", first_name: "A", last_name: "B", password: "password123") }
  let(:conversation) { Conversation.create!(organization: organization, user: user) }

  def build_message(attrs = {})
    described_class.new(
      { organization: organization, conversation: conversation,
        role: "user", content: "Hello", position: 0 }.merge(attrs)
    )
  end

  describe "associations" do
    it "belongs to organization" do
      association = described_class.reflect_on_association(:organization)
      expect(association.macro).to eq(:belongs_to)
    end

    it "belongs to conversation" do
      association = described_class.reflect_on_association(:conversation)
      expect(association.macro).to eq(:belongs_to)
    end
  end

  describe "validations" do
    it "requires a role" do
      msg = build_message(role: nil)
      msg.valid?
      expect(msg.errors[:role]).to include("can't be blank")
    end

    it "rejects an invalid role" do
      msg = build_message(role: "system")
      msg.valid?
      expect(msg.errors[:role]).to include("is not included in the list")
    end

    %w[user assistant].each do |valid_role|
      it "accepts role '#{valid_role}'" do
        msg = build_message(role: valid_role)
        expect(msg).to be_valid
      end
    end

    it "requires content" do
      msg = build_message(content: nil)
      msg.valid?
      expect(msg.errors[:content]).to include("can't be blank")
    end

    it "requires position" do
      msg = build_message(position: nil)
      msg.valid?
      expect(msg.errors[:position]).to include("can't be blank")
    end

    it "rejects duplicate position within same conversation" do
      described_class.create!(
        organization: organization, conversation: conversation,
        role: "user", content: "Hello", position: 0
      )
      duplicate = build_message(position: 0)
      duplicate.valid?
      expect(duplicate.errors[:position]).to include("has already been taken")
    end

    it "allows same position in different conversations" do
      other_conversation = Conversation.create!(organization: organization, user: user)
      described_class.create!(
        organization: organization, conversation: conversation,
        role: "user", content: "Hello", position: 0
      )
      msg = build_message(conversation: other_conversation, position: 0)
      expect(msg).to be_valid
    end
  end

  describe "defaults" do
    it "defaults citations to empty array" do
      msg = described_class.create!(
        organization: organization, conversation: conversation,
        role: "user", content: "Hello", position: 0
      )
      expect(msg.citations).to eq([])
    end
  end

  describe "AI metadata" do
    it "allows nil ai_model" do
      msg = build_message
      expect(msg).to be_valid
      expect(msg.ai_model).to be_nil
    end

    it "allows nil input_tokens" do
      msg = build_message
      expect(msg).to be_valid
      expect(msg.input_tokens).to be_nil
    end

    it "allows nil output_tokens" do
      msg = build_message
      expect(msg).to be_valid
      expect(msg.output_tokens).to be_nil
    end

    it "stores AI metadata on assistant messages" do
      msg = described_class.create!(
        organization: organization, conversation: conversation,
        role: "assistant", content: "I can help with that.",
        position: 1, ai_model: "gpt-4o", input_tokens: 150, output_tokens: 50,
        citations: [ { "chunk_id" => "abc", "score" => 0.95 } ]
      )
      msg.reload
      expect(msg.ai_model).to eq("gpt-4o")
      expect(msg.input_tokens).to eq(150)
      expect(msg.output_tokens).to eq(50)
      expect(msg.citations).to eq([ { "chunk_id" => "abc", "score" => 0.95 } ])
    end
  end

  describe "tenant isolation" do
    it "requires an organization" do
      msg = described_class.new(conversation: conversation, role: "user", content: "Hello", position: 0)
      expect(msg).not_to be_valid
      expect(msg.errors[:organization]).to include("must exist")
    end

    it "cannot be created without an organization at the database level" do
      expect {
        described_class.connection.execute(<<~SQL)
          INSERT INTO messages (id, conversation_id, role, content, position, citations, created_at)
          VALUES (gen_random_uuid(), '#{conversation.id}', 'user', 'Hello', 0, '[]', NOW())
        SQL
      }.to raise_error(ActiveRecord::NotNullViolation)
    end
  end

  describe "cross-tenant integrity" do
    let(:other_org) { Organization.create!(name: "Other", slug: "other") }
    let(:other_user) { User.create!(email: "other@example.com", first_name: "C", last_name: "D", password: "password123") }
    let(:other_conversation) { Conversation.create!(organization: other_org, user: other_user) }

    it "rejects a message referencing a conversation from a different organization at the database level" do
      expect {
        described_class.connection.execute(<<~SQL)
          INSERT INTO messages (id, organization_id, conversation_id, role, content, position, citations, created_at)
          VALUES (gen_random_uuid(), '#{organization.id}', '#{other_conversation.id}', 'user', 'Hello', 0, '[]', NOW())
        SQL
      }.to raise_error(ActiveRecord::StatementInvalid, /violates foreign key constraint "fk_messages_organization_conversation"/)
    end

    it "allows a message referencing a conversation from the same organization" do
      msg = described_class.create!(
        organization: organization, conversation: conversation,
        role: "user", content: "Hello", position: 0
      )
      expect(msg).to be_persisted
      expect(msg.organization_id).to eq(conversation.organization_id)
    end
  end

  describe "immutability" do
    it "does not have an updated_at column" do
      expect(described_class.column_names).not_to include("updated_at")
    end

    it "has a created_at column" do
      expect(described_class.column_names).to include("created_at")
    end
  end

  describe "ROLES constant" do
    it "defines exactly user and assistant" do
      expect(Message::ROLES).to eq(%w[user assistant])
    end
  end
end
