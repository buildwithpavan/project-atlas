# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ticket, type: :model do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme") }
  let(:upload) { Upload.create!(organization: organization, filename: "export.csv") }

  describe "associations" do
    it "belongs to organization" do
      association = described_class.reflect_on_association(:organization)
      expect(association.macro).to eq(:belongs_to)
    end

    it "belongs to upload" do
      association = described_class.reflect_on_association(:upload)
      expect(association.macro).to eq(:belongs_to)
    end
  end

  describe "validations" do
    it "requires a subject" do
      ticket = described_class.new(organization: organization, upload: upload, subject: nil)
      ticket.valid?
      expect(ticket.errors[:subject]).to include("can't be blank")
    end

    it "is valid with required fields" do
      ticket = described_class.new(
        organization: organization,
        upload: upload,
        subject: "Login issue"
      )
      expect(ticket).to be_valid
    end

    it "allows optional fields to be nil" do
      ticket = described_class.create!(
        organization: organization,
        upload: upload,
        subject: "Help needed"
      )
      expect(ticket.description).to be_nil
      expect(ticket.customer_name).to be_nil
      expect(ticket.customer_email).to be_nil
      expect(ticket.priority).to be_nil
      expect(ticket.status).to be_nil
      expect(ticket.category).to be_nil
    end
  end

  describe "tenant isolation" do
    it "requires an organization" do
      ticket = described_class.new(upload: upload, subject: "Test")
      expect(ticket).not_to be_valid
      expect(ticket.errors[:organization]).to include("must exist")
    end

    it "requires an upload" do
      ticket = described_class.new(organization: organization, subject: "Test")
      expect(ticket).not_to be_valid
      expect(ticket.errors[:upload]).to include("must exist")
    end

    it "cannot be created without an organization at the database level" do
      expect {
        described_class.connection.execute(<<~SQL)
          INSERT INTO tickets (id, upload_id, subject, created_at, updated_at)
          VALUES (gen_random_uuid(), '#{upload.id}', 'Test', NOW(), NOW())
        SQL
      }.to raise_error(ActiveRecord::NotNullViolation)
    end

    it "cannot be created without an upload at the database level" do
      expect {
        described_class.connection.execute(<<~SQL)
          INSERT INTO tickets (id, organization_id, subject, created_at, updated_at)
          VALUES (gen_random_uuid(), '#{organization.id}', 'Test', NOW(), NOW())
        SQL
      }.to raise_error(ActiveRecord::NotNullViolation)
    end
  end

  describe "full ticket creation" do
    it "persists all fields" do
      ticket = described_class.create!(
        organization: organization,
        upload: upload,
        subject: "Cannot reset password",
        description: "Customer tried resetting password but received no email.",
        customer_name: "Jane Doe",
        customer_email: "jane@example.com",
        priority: "high",
        status: "open",
        category: "authentication"
      )

      ticket.reload
      expect(ticket.subject).to eq("Cannot reset password")
      expect(ticket.description).to eq("Customer tried resetting password but received no email.")
      expect(ticket.customer_name).to eq("Jane Doe")
      expect(ticket.customer_email).to eq("jane@example.com")
      expect(ticket.priority).to eq("high")
      expect(ticket.status).to eq("open")
      expect(ticket.category).to eq("authentication")
    end
  end

  describe "upload relationship" do
    it "can access its upload" do
      ticket = described_class.create!(organization: organization, upload: upload, subject: "Test")
      expect(ticket.upload).to eq(upload)
    end

    it "upload can access its tickets" do
      described_class.create!(organization: organization, upload: upload, subject: "Ticket 1")
      described_class.create!(organization: organization, upload: upload, subject: "Ticket 2")
      expect(upload.tickets.count).to eq(2)
    end
  end

  describe "foreign key constraints" do
    it "prevents deletion of upload with existing tickets" do
      described_class.create!(organization: organization, upload: upload, subject: "Test")
      expect { upload.destroy }.not_to change(Upload, :count)
      expect(upload.errors[:base]).to include(/Cannot delete record because dependent tickets exist/)
    end
  end

  describe "cross-tenant integrity" do
    let(:other_organization) { Organization.create!(name: "Other Corp", slug: "other-corp") }
    let(:other_upload) { Upload.create!(organization: other_organization, filename: "other.csv") }

    it "rejects a ticket referencing an upload from a different organization at the database level" do
      expect {
        described_class.connection.execute(<<~SQL)
          INSERT INTO tickets (id, organization_id, upload_id, subject, created_at, updated_at)
          VALUES (gen_random_uuid(), '#{organization.id}', '#{other_upload.id}', 'Cross-tenant', NOW(), NOW())
        SQL
      }.to raise_error(ActiveRecord::StatementInvalid, /violates foreign key constraint "fk_tickets_organization_upload"/)
    end

    it "allows a ticket referencing an upload from the same organization" do
      ticket = described_class.create!(organization: organization, upload: upload, subject: "Same tenant")
      expect(ticket).to be_persisted
      expect(ticket.organization_id).to eq(upload.organization_id)
    end
  end
end
