# frozen_string_literal: true

require "rails_helper"

RSpec.describe AiUsageRecord, type: :model do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme-usage") }
  let(:user) do
    User.create!(email: "usage@example.com", first_name: "A", last_name: "B", password: "password123")
  end
  let!(:membership) { Membership.create!(user: user, organization: organization, role: "member") }
  let(:conversation) { Conversation.create!(organization: organization, user: user, title: "Chat") }
  let(:message) do
    Message.create!(organization: organization, conversation: conversation,
                    role: "assistant", content: "Answer", position: 0)
  end

  def build_record(attrs = {})
    AiUsageRecord.new({
      organization: organization,
      user: user,
      conversation: conversation,
      message: message,
      provider: "openai",
      model: "gpt-5.6-luna",
      operation: "chat",
      prompt_tokens: 100,
      completion_tokens: 50,
      total_tokens: 150,
      estimated_cost: 0.001250,
      request_id: "req-123",
      latency_ms: 500
    }.merge(attrs))
  end

  describe "validations" do
    it "is valid with all attributes" do
      expect(build_record).to be_valid
    end

    it "requires provider" do
      expect(build_record(provider: nil)).not_to be_valid
    end

    it "requires model" do
      expect(build_record(model: nil)).not_to be_valid
    end

    it "requires operation" do
      expect(build_record(operation: nil)).not_to be_valid
    end

    it "requires valid operation" do
      expect(build_record(operation: "translate")).not_to be_valid
    end

    it "requires valid provider" do
      expect(build_record(provider: "anthropic")).not_to be_valid
    end

    it "allows chat operation" do
      expect(build_record(operation: "chat")).to be_valid
    end

    it "allows embedding operation" do
      expect(build_record(operation: "embedding")).to be_valid
    end

    it "requires non-negative prompt_tokens" do
      expect(build_record(prompt_tokens: -1)).not_to be_valid
    end

    it "requires non-negative completion_tokens" do
      expect(build_record(completion_tokens: -1)).not_to be_valid
    end

    it "requires non-negative total_tokens" do
      expect(build_record(total_tokens: -1)).not_to be_valid
    end

    it "requires non-negative estimated_cost" do
      expect(build_record(estimated_cost: -0.01)).not_to be_valid
    end

    it "allows zero token values" do
      record = build_record(prompt_tokens: 0, completion_tokens: 0, total_tokens: 0, estimated_cost: 0)
      expect(record).to be_valid
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

    it "optionally belongs to message" do
      record = build_record(message: nil)
      expect(record).to be_valid
    end
  end

  describe "persistence" do
    it "saves a valid record" do
      record = build_record
      expect { record.save! }.to change(AiUsageRecord, :count).by(1)
    end

    it "preserves decimal precision for estimated_cost" do
      record = build_record(estimated_cost: 0.000016)
      record.save!
      expect(record.reload.estimated_cost.to_f).to eq(0.000016)
    end
  end
end
