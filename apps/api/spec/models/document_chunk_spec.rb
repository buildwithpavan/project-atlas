# frozen_string_literal: true

require "rails_helper"

RSpec.describe DocumentChunk, type: :model do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme") }
  let(:document) do
    Document.create!(
      organization: organization, title: "Guide", filename: "guide.pdf",
      content_type: "application/pdf", file_size: 1024
    )
  end

  describe "associations" do
    it "belongs to organization" do
      association = described_class.reflect_on_association(:organization)
      expect(association.macro).to eq(:belongs_to)
    end

    it "belongs to document" do
      association = described_class.reflect_on_association(:document)
      expect(association.macro).to eq(:belongs_to)
    end
  end

  describe "validations" do
    it "requires content" do
      chunk = described_class.new(organization: organization, document: document, position: 0, content: nil)
      chunk.valid?
      expect(chunk.errors[:content]).to include("can't be blank")
    end

    it "requires position" do
      chunk = described_class.new(organization: organization, document: document, content: "text", position: nil)
      chunk.valid?
      expect(chunk.errors[:position]).to include("can't be blank")
    end

    it "rejects duplicate position within same document" do
      described_class.create!(organization: organization, document: document, content: "chunk 1", position: 0)
      duplicate = described_class.new(organization: organization, document: document, content: "chunk 2", position: 0)
      duplicate.valid?
      expect(duplicate.errors[:position]).to include("has already been taken")
    end

    it "allows same position in different documents" do
      other_doc = Document.create!(
        organization: organization, title: "Other", filename: "other.pdf",
        content_type: "application/pdf", file_size: 512
      )
      described_class.create!(organization: organization, document: document, content: "chunk 1", position: 0)
      chunk = described_class.new(organization: organization, document: other_doc, content: "chunk 2", position: 0)
      expect(chunk).to be_valid
    end
  end

  describe "defaults" do
    it "defaults metadata to empty hash" do
      chunk = described_class.create!(organization: organization, document: document, content: "text", position: 0)
      expect(chunk.metadata).to eq({})
    end
  end

  describe "tenant isolation" do
    it "requires an organization" do
      chunk = described_class.new(document: document, content: "text", position: 0)
      expect(chunk).not_to be_valid
      expect(chunk.errors[:organization]).to include("must exist")
    end

    it "cannot be created without an organization at the database level" do
      expect {
        described_class.connection.execute(<<~SQL)
          INSERT INTO document_chunks (id, document_id, content, position, metadata, created_at)
          VALUES (gen_random_uuid(), '#{document.id}', 'text', 0, '{}', NOW())
        SQL
      }.to raise_error(ActiveRecord::NotNullViolation)
    end
  end

  describe "cross-tenant integrity" do
    let(:other_org) { Organization.create!(name: "Other", slug: "other") }
    let(:other_document) do
      Document.create!(
        organization: other_org, title: "Other Guide", filename: "other.pdf",
        content_type: "application/pdf", file_size: 512
      )
    end

    it "rejects a chunk referencing a document from a different organization at the database level" do
      expect {
        described_class.connection.execute(<<~SQL)
          INSERT INTO document_chunks (id, organization_id, document_id, content, position, metadata, created_at)
          VALUES (gen_random_uuid(), '#{organization.id}', '#{other_document.id}', 'text', 0, '{}', NOW())
        SQL
      }.to raise_error(ActiveRecord::StatementInvalid, /violates foreign key constraint "fk_document_chunks_organization_document"/)
    end

    it "allows a chunk referencing a document from the same organization" do
      chunk = described_class.create!(organization: organization, document: document, content: "text", position: 0)
      expect(chunk).to be_persisted
      expect(chunk.organization_id).to eq(document.organization_id)
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
end
