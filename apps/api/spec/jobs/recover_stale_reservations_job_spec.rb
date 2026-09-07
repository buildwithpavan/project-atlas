# frozen_string_literal: true

require "rails_helper"

RSpec.describe RecoverStaleReservationsJob, type: :job do
  let(:organization) { Organization.create!(name: "RecoveryOrg", slug: "recovery-org") }
  let(:user) do
    User.create!(email: "recovery@example.com", first_name: "R", last_name: "J", password: "password123")
  end
  let!(:membership) { Membership.create!(user: user, organization: organization, role: "member") }

  describe "#perform" do
    it "resets stale reservations" do
      organization.update!(
        ai_monthly_token_limit: 10_000,
        ai_quota_reserved_tokens: 1_000,
        ai_quota_reserved_at: 10.minutes.ago
      )

      described_class.perform_now

      organization.reload
      expect(organization.ai_quota_reserved_tokens).to eq(0)
      expect(organization.ai_quota_reserved_at).to be_nil
    end

    it "does not reset recent reservations" do
      organization.update!(
        ai_monthly_token_limit: 10_000,
        ai_quota_reserved_tokens: 1_000,
        ai_quota_reserved_at: 1.minute.ago
      )

      described_class.perform_now

      organization.reload
      expect(organization.ai_quota_reserved_tokens).to eq(1_000)
      expect(organization.ai_quota_reserved_at).to be_present
    end

    it "does not reset reservations without a timestamp" do
      organization.update!(
        ai_monthly_token_limit: 10_000,
        ai_quota_reserved_tokens: 500,
        ai_quota_reserved_at: nil
      )

      described_class.perform_now

      organization.reload
      expect(organization.ai_quota_reserved_tokens).to eq(500)
    end

    it "does not touch organizations with zero reservations" do
      organization.update!(
        ai_monthly_token_limit: 10_000,
        ai_quota_reserved_tokens: 0,
        ai_quota_reserved_at: 10.minutes.ago
      )

      described_class.perform_now

      organization.reload
      expect(organization.ai_quota_reserved_tokens).to eq(0)
    end

    it "recovers across multiple organizations" do
      org2 = Organization.create!(name: "Org2", slug: "org2")
      org3 = Organization.create!(name: "Org3", slug: "org3")

      organization.update!(ai_monthly_token_limit: 10_000, ai_quota_reserved_tokens: 500, ai_quota_reserved_at: 10.minutes.ago)
      org2.update!(ai_monthly_token_limit: 10_000, ai_quota_reserved_tokens: 300, ai_quota_reserved_at: 10.minutes.ago)
      org3.update!(ai_monthly_token_limit: 10_000, ai_quota_reserved_tokens: 700, ai_quota_reserved_at: 1.minute.ago) # recent

      described_class.perform_now

      expect(organization.reload.ai_quota_reserved_tokens).to eq(0)
      expect(org2.reload.ai_quota_reserved_tokens).to eq(0)
      expect(org3.reload.ai_quota_reserved_tokens).to eq(700) # untouched
    end

    it "is idempotent" do
      organization.update!(
        ai_monthly_token_limit: 10_000,
        ai_quota_reserved_tokens: 1_000,
        ai_quota_reserved_at: 10.minutes.ago
      )

      described_class.perform_now
      described_class.perform_now

      organization.reload
      expect(organization.ai_quota_reserved_tokens).to eq(0)
    end
  end
end
