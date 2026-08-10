# frozen_string_literal: true

require "rails_helper"

RSpec.describe AiAnalysis, type: :model do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme") }
  let(:upload) { Upload.create!(organization: organization, filename: "test.csv") }
  let(:ticket) { Ticket.create!(organization: organization, upload: upload, subject: "Help needed") }

  describe "associations" do
    it "belongs to organization" do
      association = described_class.reflect_on_association(:organization)
      expect(association.macro).to eq(:belongs_to)
    end

    it "belongs to ticket" do
      association = described_class.reflect_on_association(:ticket)
      expect(association.macro).to eq(:belongs_to)
    end
  end

  describe "validations" do
    it "requires a status" do
      analysis = described_class.new(organization: organization, ticket: ticket, status: nil)
      analysis.valid?
      expect(analysis.errors[:status]).to include("can't be blank")
    end

    it "rejects invalid status" do
      analysis = described_class.new(organization: organization, ticket: ticket, status: "unknown")
      analysis.valid?
      expect(analysis.errors[:status]).to include("is not included in the list")
    end

    %w[pending processing completed failed].each do |valid_status|
      it "accepts status '#{valid_status}'" do
        analysis = described_class.new(organization: organization, ticket: ticket, status: valid_status)
        expect(analysis.errors[:status]).to be_empty if analysis.valid?
      end
    end

    it "rejects invalid sentiment" do
      analysis = described_class.new(organization: organization, ticket: ticket, sentiment: "angry")
      analysis.valid?
      expect(analysis.errors[:sentiment]).to include("is not included in the list")
    end

    %w[positive negative neutral mixed].each do |valid_sentiment|
      it "accepts sentiment '#{valid_sentiment}'" do
        analysis = described_class.new(organization: organization, ticket: ticket, sentiment: valid_sentiment)
        analysis.valid?
        expect(analysis.errors[:sentiment]).to be_empty
      end
    end

    it "allows nil sentiment" do
      analysis = described_class.new(organization: organization, ticket: ticket)
      analysis.valid?
      expect(analysis.errors[:sentiment]).to be_empty
    end

    it "rejects confidence > 1" do
      analysis = described_class.new(organization: organization, ticket: ticket, confidence: 1.5)
      analysis.valid?
      expect(analysis.errors[:confidence]).to be_present
    end

    it "rejects confidence < 0" do
      analysis = described_class.new(organization: organization, ticket: ticket, confidence: -0.1)
      analysis.valid?
      expect(analysis.errors[:confidence]).to be_present
    end

    it "accepts confidence between 0 and 1" do
      analysis = described_class.new(organization: organization, ticket: ticket, confidence: 0.85)
      analysis.valid?
      expect(analysis.errors[:confidence]).to be_empty
    end
  end

  describe "defaults" do
    it "defaults status to pending" do
      analysis = described_class.new(organization: organization, ticket: ticket)
      expect(analysis.status).to eq("pending")
    end
  end

  describe "uniqueness" do
    it "allows only one analysis per ticket" do
      described_class.create!(organization: organization, ticket: ticket)
      duplicate = described_class.new(organization: organization, ticket: ticket)
      expect {
        duplicate.save!(validate: false)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "tenant isolation" do
    it "requires an organization" do
      analysis = described_class.new(ticket: ticket)
      expect(analysis).not_to be_valid
      expect(analysis.errors[:organization]).to include("must exist")
    end

    it "cannot be created without an organization at the database level" do
      expect {
        described_class.connection.execute(<<~SQL)
          INSERT INTO ai_analyses (id, ticket_id, status, created_at, updated_at)
          VALUES (gen_random_uuid(), '#{ticket.id}', 'pending', NOW(), NOW())
        SQL
      }.to raise_error(ActiveRecord::NotNullViolation)
    end
  end

  describe "cross-tenant integrity" do
    let(:other_org) { Organization.create!(name: "Other", slug: "other") }
    let(:other_upload) { Upload.create!(organization: other_org, filename: "other.csv") }
    let(:other_ticket) { Ticket.create!(organization: other_org, upload: other_upload, subject: "Other") }

    it "rejects an analysis referencing a ticket from a different organization at the database level" do
      expect {
        described_class.connection.execute(<<~SQL)
          INSERT INTO ai_analyses (id, organization_id, ticket_id, status, created_at, updated_at)
          VALUES (gen_random_uuid(), '#{organization.id}', '#{other_ticket.id}', 'pending', NOW(), NOW())
        SQL
      }.to raise_error(ActiveRecord::StatementInvalid, /violates foreign key constraint "fk_ai_analyses_organization_ticket"/)
    end

    it "allows an analysis referencing a ticket from the same organization" do
      analysis = described_class.create!(organization: organization, ticket: ticket)
      expect(analysis).to be_persisted
      expect(analysis.organization_id).to eq(ticket.organization_id)
    end
  end

  describe "ticket relationship" do
    it "is accessible from ticket via has_one" do
      analysis = described_class.create!(organization: organization, ticket: ticket)
      expect(ticket.reload.ai_analysis).to eq(analysis)
    end
  end

  describe "STATUSES constant" do
    it "defines exactly pending, processing, completed, failed" do
      expect(AiAnalysis::STATUSES).to eq(%w[pending processing completed failed])
    end
  end

  describe "SENTIMENTS constant" do
    it "defines positive, negative, neutral, mixed" do
      expect(AiAnalysis::SENTIMENTS).to eq(%w[positive negative neutral mixed])
    end
  end
end
