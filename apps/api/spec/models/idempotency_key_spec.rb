# frozen_string_literal: true

require "rails_helper"

RSpec.describe IdempotencyKey, type: :model do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme-idem") }
  let(:user) do
    User.create!(email: "idem@example.com", first_name: "A", last_name: "B", password: "password123")
  end
  let!(:membership) { Membership.create!(user: user, organization: organization, role: "member") }
  let(:conversation) { Conversation.create!(organization: organization, user: user, title: "Chat") }

  describe "validations" do
    it "requires key" do
      record = IdempotencyKey.new(
        organization: organization, user: user, conversation: conversation,
        request_fingerprint: "abc123"
      )
      expect(record).not_to be_valid
      expect(record.errors[:key]).to be_present
    end

    it "requires request_fingerprint" do
      record = IdempotencyKey.new(
        organization: organization, user: user, conversation: conversation,
        key: "test-key"
      )
      expect(record).not_to be_valid
      expect(record.errors[:request_fingerprint]).to be_present
    end

    it "requires conversation" do
      record = IdempotencyKey.new(
        organization: organization, user: user,
        key: "test-key", request_fingerprint: "abc123"
      )
      expect(record).not_to be_valid
    end

    it "is valid with required attributes" do
      record = IdempotencyKey.new(
        organization: organization, user: user, conversation: conversation,
        key: "test-key", request_fingerprint: "abc123"
      )
      expect(record).to be_valid
    end
  end

  describe "uniqueness" do
    it "enforces unique key per organization + user + conversation at database level" do
      IdempotencyKey.create!(
        organization: organization, user: user, conversation: conversation,
        key: "dup-key", request_fingerprint: "fp1"
      )

      expect {
        IdempotencyKey.connection.execute(
          ApplicationRecord.sanitize_sql_array([
            "INSERT INTO idempotency_keys (id, organization_id, user_id, key, conversation_id, request_fingerprint, created_at) VALUES (gen_random_uuid(), ?, ?, ?, ?, ?, NOW())",
            organization.id, user.id, "dup-key", conversation.id, "fp2"
          ])
        )
      }.to raise_error(ActiveRecord::StatementInvalid, /violates unique constraint|duplicate key/)
    end

    it "allows same key for same user in different conversations" do
      other_conv = Conversation.create!(organization: organization, user: user, title: "Other")
      IdempotencyKey.create!(
        organization: organization, user: user, conversation: conversation,
        key: "conv-key", request_fingerprint: "fp1"
      )
      record2 = IdempotencyKey.new(
        organization: organization, user: user, conversation: other_conv,
        key: "conv-key", request_fingerprint: "fp2"
      )
      expect(record2).to be_valid
    end

    it "allows same key for different users" do
      other_user = User.create!(email: "other-idem@example.com", first_name: "C", last_name: "D", password: "password123")
      Membership.create!(user: other_user, organization: organization, role: "member")

      IdempotencyKey.create!(
        organization: organization, user: user, conversation: conversation,
        key: "shared-key", request_fingerprint: "fp1"
      )
      record2 = IdempotencyKey.new(
        organization: organization, user: other_user, conversation: conversation,
        key: "shared-key", request_fingerprint: "fp2"
      )
      expect(record2).to be_valid
    end

    it "allows same key for different organizations" do
      other_org = Organization.create!(name: "Other", slug: "other-idem")
      other_user = User.create!(email: "ext-idem@example.com", first_name: "E", last_name: "F", password: "password123")
      Membership.create!(user: other_user, organization: other_org, role: "member")
      other_conv = Conversation.create!(organization: other_org, user: other_user, title: "Other Chat")

      IdempotencyKey.create!(
        organization: organization, user: user, conversation: conversation,
        key: "cross-org-key", request_fingerprint: "fp1"
      )
      record2 = IdempotencyKey.new(
        organization: other_org, user: other_user, conversation: other_conv,
        key: "cross-org-key", request_fingerprint: "fp2"
      )
      expect(record2).to be_valid
    end
  end

  describe "associations" do
    it "belongs to organization" do
      expect(described_class.reflect_on_association(:organization).macro).to eq(:belongs_to)
    end

    it "belongs to user" do
      expect(described_class.reflect_on_association(:user).macro).to eq(:belongs_to)
    end

    it "belongs to conversation" do
      expect(described_class.reflect_on_association(:conversation).macro).to eq(:belongs_to)
    end

    it "optionally belongs to user_message" do
      record = IdempotencyKey.create!(
        organization: organization, user: user, conversation: conversation,
        key: "no-msg", request_fingerprint: "fp"
      )
      expect(record.user_message).to be_nil
    end

    it "optionally belongs to assistant_message" do
      record = IdempotencyKey.create!(
        organization: organization, user: user, conversation: conversation,
        key: "no-assistant", request_fingerprint: "fp"
      )
      expect(record.assistant_message).to be_nil
    end
  end
end
