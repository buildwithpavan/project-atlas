# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::QuotaEnforcer, type: :service do
  let(:organization) { Organization.create!(name: "QuotaOrg", slug: "quota-org-#{SecureRandom.hex(4)}") }
  let(:user) do
    User.create!(email: "quota-#{SecureRandom.hex(4)}@example.com", first_name: "Q", last_name: "U", password: "password123")
  end
  let!(:membership) { Membership.create!(user: user, organization: organization, role: "member") }
  let(:conversation) { Conversation.create!(organization: organization, user: user, title: "Chat") }

  def create_usage(tokens:, cost:, created_at: Time.current)
    AiUsageRecord.create!(
      organization: organization,
      user: user,
      conversation: conversation,
      provider: "openai",
      model: "gpt-5.6-luna",
      operation: "chat",
      prompt_tokens: tokens,
      completion_tokens: 0,
      total_tokens: tokens,
      estimated_cost: cost,
      created_at: created_at
    )
  end

  describe "when no limits are configured" do
    it "does not raise" do
      expect { described_class.call(organization: organization) }.not_to raise_error
    end

    it "does not raise even with heavy usage" do
      create_usage(tokens: 10_000_000, cost: 500.0)
      expect { described_class.call(organization: organization) }.not_to raise_error
    end
  end

  describe "token limit enforcement" do
    before { organization.update!(ai_monthly_token_limit: 10_000) }

    it "allows requests under the limit" do
      create_usage(tokens: 5_000, cost: 0.01)
      expect { described_class.call(organization: organization) }.not_to raise_error
    end

    it "raises AiQuotaExceededError when at the limit" do
      create_usage(tokens: 10_000, cost: 0.01)
      expect { described_class.call(organization: organization) }
        .to raise_error(AiQuotaExceededError) { |e|
          expect(e.limit_type).to eq("token")
          expect(e.current_value).to eq(10_000)
          expect(e.limit_value).to eq(10_000)
        }
    end

    it "raises AiQuotaExceededError when over the limit" do
      create_usage(tokens: 15_000, cost: 0.01)
      expect { described_class.call(organization: organization) }
        .to raise_error(AiQuotaExceededError)
    end

    it "aggregates across multiple usage records" do
      create_usage(tokens: 4_000, cost: 0.01)
      create_usage(tokens: 4_000, cost: 0.01)
      expect { described_class.call(organization: organization) }.not_to raise_error

      create_usage(tokens: 3_000, cost: 0.01)
      expect { described_class.call(organization: organization) }
        .to raise_error(AiQuotaExceededError)
    end

    it "ignores usage from previous months" do
      create_usage(tokens: 15_000, cost: 0.01, created_at: 2.months.ago)
      expect { described_class.call(organization: organization) }.not_to raise_error
    end
  end

  describe "cost limit enforcement" do
    before { organization.update!(ai_monthly_cost_limit: 10.0) }

    it "allows requests under the limit" do
      create_usage(tokens: 100, cost: 5.0)
      expect { described_class.call(organization: organization) }.not_to raise_error
    end

    it "raises AiQuotaExceededError when at the limit" do
      create_usage(tokens: 100, cost: 10.0)
      expect { described_class.call(organization: organization) }
        .to raise_error(AiQuotaExceededError) { |e|
          expect(e.limit_type).to eq("cost")
        }
    end

    it "raises AiQuotaExceededError when over the limit" do
      create_usage(tokens: 100, cost: 15.0)
      expect { described_class.call(organization: organization) }
        .to raise_error(AiQuotaExceededError)
    end

    it "ignores usage from previous months" do
      create_usage(tokens: 100, cost: 15.0, created_at: 2.months.ago)
      expect { described_class.call(organization: organization) }.not_to raise_error
    end
  end

  describe "combined limits" do
    before do
      organization.update!(ai_monthly_token_limit: 10_000, ai_monthly_cost_limit: 10.0)
    end

    it "allows when both under limits" do
      create_usage(tokens: 5_000, cost: 5.0)
      expect { described_class.call(organization: organization) }.not_to raise_error
    end

    it "raises when tokens exceeded even if cost is under" do
      create_usage(tokens: 12_000, cost: 1.0)
      expect { described_class.call(organization: organization) }
        .to raise_error(AiQuotaExceededError) { |e|
          expect(e.limit_type).to eq("token")
        }
    end

    it "raises when cost exceeded even if tokens are under" do
      create_usage(tokens: 1_000, cost: 15.0)
      expect { described_class.call(organization: organization) }
        .to raise_error(AiQuotaExceededError) { |e|
          expect(e.limit_type).to eq("cost")
        }
    end
  end

  describe "tenant isolation" do
    let(:other_org) { Organization.create!(name: "Other", slug: "other-#{SecureRandom.hex(4)}") }
    let(:other_user) do
      User.create!(email: "other-#{SecureRandom.hex(4)}@example.com", first_name: "O", last_name: "T", password: "password123")
    end
    let!(:other_membership) { Membership.create!(user: other_user, organization: other_org, role: "member") }
    let(:other_conversation) { Conversation.create!(organization: other_org, user: other_user, title: "Other") }

    before { organization.update!(ai_monthly_token_limit: 10_000) }

    it "does not count usage from other organizations" do
      AiUsageRecord.create!(
        organization: other_org,
        user: other_user,
        conversation: other_conversation,
        provider: "openai",
        model: "gpt-5.6-luna",
        operation: "chat",
        prompt_tokens: 50_000,
        completion_tokens: 0,
        total_tokens: 50_000,
        estimated_cost: 100.0
      )

      expect { described_class.call(organization: organization) }.not_to raise_error
    end
  end

  describe "observability" do
    before { organization.update!(ai_monthly_token_limit: 100) }

    it "logs quota enforcement decisions" do
      create_usage(tokens: 200, cost: 0.01)
      allow(Rails.logger).to receive(:info)

      expect { described_class.call(organization: organization) }
        .to raise_error(AiQuotaExceededError)

      expect(Rails.logger).to have_received(:info).with(/\[AiQuota\].*token_limit_exceeded/)
    end
  end

  describe ".reserve!" do
    before { organization.update!(ai_monthly_token_limit: 10_000) }

    it "atomically increments reservation counter" do
      described_class.reserve!(organization: organization, estimated_tokens: 500)
      expect(organization.reload.ai_quota_reserved_tokens).to eq(500)
    end

    it "sets the reservation timestamp" do
      freeze_time do
        described_class.reserve!(organization: organization, estimated_tokens: 500)
        expect(organization.reload.ai_quota_reserved_at).to be_within(1.second).of(Time.current)
      end
    end

    it "allows reservation when under limit" do
      create_usage(tokens: 5_000, cost: 0.01)
      expect { described_class.reserve!(organization: organization, estimated_tokens: 500) }
        .not_to raise_error
    end

    it "accumulates multiple reservations" do
      described_class.reserve!(organization: organization, estimated_tokens: 500)
      described_class.reserve!(organization: organization, estimated_tokens: 300)
      expect(organization.reload.ai_quota_reserved_tokens).to eq(800)
    end

    it "skips reservation when limit is nil (unlimited)" do
      organization.update!(ai_monthly_token_limit: nil)
      described_class.reserve!(organization: organization, estimated_tokens: 500)
      expect(organization.reload.ai_quota_reserved_tokens).to eq(0)
    end
  end

  describe ".release_reservation!" do
    before { organization.update!(ai_monthly_token_limit: 10_000) }

    it "decrements reservation counter" do
      described_class.reserve!(organization: organization, estimated_tokens: 500)
      described_class.release_reservation!(organization: organization, estimated_tokens: 500)
      expect(organization.reload.ai_quota_reserved_tokens).to eq(0)
    end

    it "clears timestamp when counter reaches zero" do
      described_class.reserve!(organization: organization, estimated_tokens: 500)
      described_class.release_reservation!(organization: organization, estimated_tokens: 500)
      expect(organization.reload.ai_quota_reserved_at).to be_nil
    end

    it "preserves timestamp when partial release" do
      described_class.reserve!(organization: organization, estimated_tokens: 500)
      described_class.reserve!(organization: organization, estimated_tokens: 300)
      described_class.release_reservation!(organization: organization, estimated_tokens: 500)
      org = organization.reload
      expect(org.ai_quota_reserved_tokens).to eq(300)
      expect(org.ai_quota_reserved_at).to be_present
    end

    it "does not go below zero" do
      described_class.release_reservation!(organization: organization, estimated_tokens: 500)
      expect(organization.reload.ai_quota_reserved_tokens).to eq(0)
    end
  end

  describe ".recover_stale_reservations!" do
    it "resets reservations older than expiry threshold" do
      organization.update!(
        ai_monthly_token_limit: 10_000,
        ai_quota_reserved_tokens: 1_000,
        ai_quota_reserved_at: 10.minutes.ago
      )

      recovered = described_class.recover_stale_reservations!
      expect(recovered).to eq(1)

      org = organization.reload
      expect(org.ai_quota_reserved_tokens).to eq(0)
      expect(org.ai_quota_reserved_at).to be_nil
    end

    it "does not reset recent reservations" do
      organization.update!(
        ai_monthly_token_limit: 10_000,
        ai_quota_reserved_tokens: 1_000,
        ai_quota_reserved_at: 1.minute.ago
      )

      recovered = described_class.recover_stale_reservations!
      expect(recovered).to eq(0)
      expect(organization.reload.ai_quota_reserved_tokens).to eq(1_000)
    end

    it "does not reset reservations with nil timestamp" do
      organization.update!(
        ai_monthly_token_limit: 10_000,
        ai_quota_reserved_tokens: 500,
        ai_quota_reserved_at: nil
      )

      recovered = described_class.recover_stale_reservations!
      expect(recovered).to eq(0)
      expect(organization.reload.ai_quota_reserved_tokens).to eq(500)
    end

    it "does not affect organizations with zero reservations" do
      organization.update!(
        ai_monthly_token_limit: 10_000,
        ai_quota_reserved_tokens: 0,
        ai_quota_reserved_at: 10.minutes.ago
      )

      recovered = described_class.recover_stale_reservations!
      expect(recovered).to eq(0)
    end

    it "returns the number of recovered organizations" do
      org2 = Organization.create!(name: "Org2", slug: "org2-#{SecureRandom.hex(4)}")

      organization.update!(ai_monthly_token_limit: 10_000, ai_quota_reserved_tokens: 500, ai_quota_reserved_at: 10.minutes.ago)
      org2.update!(ai_monthly_token_limit: 10_000, ai_quota_reserved_tokens: 300, ai_quota_reserved_at: 10.minutes.ago)

      recovered = described_class.recover_stale_reservations!
      expect(recovered).to eq(2)
    end

    it "is idempotent" do
      organization.update!(
        ai_monthly_token_limit: 10_000,
        ai_quota_reserved_tokens: 1_000,
        ai_quota_reserved_at: 10.minutes.ago
      )

      described_class.recover_stale_reservations!
      recovered = described_class.recover_stale_reservations!
      expect(recovered).to eq(0)
    end
  end

  describe "concurrency safety" do
    before { organization.update!(ai_monthly_token_limit: 2_000) }

    it "prevents two concurrent requests from both passing quota via reserved tokens" do
      # Simulate: first request reserves tokens
      described_class.reserve!(organization: organization, estimated_tokens: 1_500)

      # Second request runs call() which sees the reservation
      create_usage(tokens: 400, cost: 0.01)
      # 400 (used) + 1500 (reserved) = 1900, below 2000 — passes
      expect { described_class.call(organization: organization) }.not_to raise_error

      # Add more usage to push over
      create_usage(tokens: 500, cost: 0.01)
      # 900 (used) + 1500 (reserved) = 2400, above 2000 — blocked
      expect { described_class.call(organization: organization) }
        .to raise_error(AiQuotaExceededError)
    end

    it "token check includes reserved tokens" do
      organization.update!(ai_quota_reserved_tokens: 9_000)
      create_usage(tokens: 500, cost: 0.01)

      expect { described_class.call(organization: organization) }
        .to raise_error(AiQuotaExceededError)
    end
  end
end
