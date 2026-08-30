# frozen_string_literal: true

require "rails_helper"

RSpec.describe CleanupAiUsageRecordsJob, type: :job do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme") }
  let(:user) do
    User.create!(email: "user@example.com", first_name: "A", last_name: "B", password: "password123")
  end
  let!(:membership) { Membership.create!(user: user, organization: organization, role: "member") }
  let(:conversation) { Conversation.create!(organization: organization, user: user, title: "Test") }

  def create_usage(created_at: Time.current)
    AiUsageRecord.create!(
      organization: organization, user: user, conversation: conversation,
      provider: "openai", model: "gpt-5.6-luna", operation: "chat",
      prompt_tokens: 100, completion_tokens: 50, total_tokens: 150,
      estimated_cost: 0.01, created_at: created_at
    )
  end

  describe "#perform" do
    it "deletes records older than the retention period" do
      old_record = create_usage(created_at: 13.months.ago)
      recent_record = create_usage(created_at: 1.month.ago)

      described_class.new.perform

      expect(AiUsageRecord.exists?(old_record.id)).to be false
      expect(AiUsageRecord.exists?(recent_record.id)).to be true
    end

    it "preserves records within the retention period" do
      record = create_usage(created_at: 6.months.ago)
      described_class.new.perform
      expect(AiUsageRecord.exists?(record.id)).to be true
    end

    it "is idempotent" do
      create_usage(created_at: 13.months.ago)

      described_class.new.perform
      count_after_first = AiUsageRecord.count

      described_class.new.perform
      expect(AiUsageRecord.count).to eq(count_after_first)
    end

    it "handles empty table gracefully" do
      expect { described_class.new.perform }.not_to raise_error
    end

    it "logs cleanup activity" do
      create_usage(created_at: 13.months.ago)
      allow(Rails.logger).to receive(:info)

      described_class.new.perform

      expect(Rails.logger).to have_received(:info).with(/\[AiUsageCleanup\].*Starting/)
      expect(Rails.logger).to have_received(:info).with(/\[AiUsageCleanup\].*Completed/)
    end
  end
end
