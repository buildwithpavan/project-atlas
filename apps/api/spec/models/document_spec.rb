# frozen_string_literal: true

require "rails_helper"

RSpec.describe Document, type: :model do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme") }
  let(:user) { User.create!(email: "user@example.com", first_name: "A", last_name: "B", password: "password123") }

  def build_document(attrs = {})
    described_class.new(
      { organization: organization, title: "Guide", filename: "guide.pdf",
        content_type: "application/pdf", file_size: 1024 }.merge(attrs)
    )
  end

  describe "associations" do
    it "belongs to organization" do
      association = described_class.reflect_on_association(:organization)
      expect(association.macro).to eq(:belongs_to)
    end

    it "belongs to uploaded_by (User)" do
      association = described_class.reflect_on_association(:uploaded_by)
      expect(association.macro).to eq(:belongs_to)
      expect(association.options[:class_name]).to eq("User")
      expect(association.options[:optional]).to eq(true)
    end

    it "has many document_chunks" do
      association = described_class.reflect_on_association(:document_chunks)
      expect(association.macro).to eq(:has_many)
      expect(association.options[:dependent]).to eq(:destroy)
    end
  end

  describe "validations" do
    it "requires a title" do
      doc = build_document(title: nil)
      doc.valid?
      expect(doc.errors[:title]).to include("can't be blank")
    end

    it "requires a filename" do
      doc = build_document(filename: nil)
      doc.valid?
      expect(doc.errors[:filename]).to include("can't be blank")
    end

    it "requires a content_type" do
      doc = build_document(content_type: nil)
      doc.valid?
      expect(doc.errors[:content_type]).to include("can't be blank")
    end

    it "requires a file_size" do
      doc = build_document(file_size: nil)
      doc.valid?
      expect(doc.errors[:file_size]).to include("can't be blank")
    end

    it "requires a status" do
      doc = build_document(status: nil)
      doc.valid?
      expect(doc.errors[:status]).to include("can't be blank")
    end

    it "rejects an invalid status" do
      doc = build_document(status: "unknown")
      doc.valid?
      expect(doc.errors[:status]).to include("is not included in the list")
    end

    %w[pending processing completed failed].each do |valid_status|
      it "accepts status '#{valid_status}'" do
        doc = build_document(status: valid_status)
        expect(doc).to be_valid
      end
    end

    it "rejects duplicate checksum within same organization" do
      described_class.create!(
        organization: organization, title: "First", filename: "a.pdf",
        content_type: "application/pdf", file_size: 100, checksum: "abc123"
      )
      duplicate = build_document(checksum: "abc123")
      duplicate.valid?
      expect(duplicate.errors[:checksum]).to include("has already been taken")
    end

    it "allows same checksum in different organizations" do
      other_org = Organization.create!(name: "Other", slug: "other")
      described_class.create!(
        organization: organization, title: "First", filename: "a.pdf",
        content_type: "application/pdf", file_size: 100, checksum: "abc123"
      )
      doc = build_document(organization: other_org, checksum: "abc123")
      expect(doc).to be_valid
    end

    it "allows nil checksum" do
      doc = build_document(checksum: nil)
      expect(doc).to be_valid
    end
  end

  describe "defaults" do
    it "defaults status to pending" do
      doc = build_document
      expect(doc.status).to eq("pending")
    end

    it "defaults chunk_count to 0" do
      doc = described_class.create!(
        organization: organization, title: "Guide", filename: "guide.pdf",
        content_type: "application/pdf", file_size: 1024
      )
      expect(doc.chunk_count).to eq(0)
    end

    it "defaults metadata to empty hash" do
      doc = described_class.create!(
        organization: organization, title: "Guide", filename: "guide.pdf",
        content_type: "application/pdf", file_size: 1024
      )
      expect(doc.metadata).to eq({})
    end
  end

  describe "tenant isolation" do
    it "requires an organization" do
      doc = described_class.new(title: "Guide", filename: "guide.pdf",
                                content_type: "application/pdf", file_size: 1024)
      expect(doc).not_to be_valid
      expect(doc.errors[:organization]).to include("must exist")
    end

    it "cannot be created without an organization at the database level" do
      expect {
        described_class.connection.execute(<<~SQL)
          INSERT INTO documents (id, title, filename, content_type, file_size, status, chunk_count, metadata, created_at, updated_at)
          VALUES (gen_random_uuid(), 'Guide', 'guide.pdf', 'application/pdf', 1024, 'pending', 0, '{}', NOW(), NOW())
        SQL
      }.to raise_error(ActiveRecord::NotNullViolation)
    end
  end

  describe "uploaded_by relationship" do
    it "can reference the uploading user" do
      doc = described_class.create!(
        organization: organization, title: "Guide", filename: "guide.pdf",
        content_type: "application/pdf", file_size: 1024, uploaded_by: user
      )
      expect(doc.reload.uploaded_by).to eq(user)
    end

    it "allows uploaded_by to be nil" do
      doc = described_class.create!(
        organization: organization, title: "Guide", filename: "guide.pdf",
        content_type: "application/pdf", file_size: 1024
      )
      expect(doc.uploaded_by).to be_nil
    end
  end

  describe "STATUSES constant" do
    it "defines exactly pending, processing, completed, failed" do
      expect(Document::STATUSES).to eq(%w[pending processing completed failed])
    end
  end
end
