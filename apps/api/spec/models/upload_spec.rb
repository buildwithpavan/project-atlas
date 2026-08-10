# frozen_string_literal: true

require "rails_helper"

RSpec.describe Upload, type: :model do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme") }
  let(:user) { User.create!(email: "user@example.com", first_name: "A", last_name: "B", password: "password123") }

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

    it "has many tickets" do
      association = described_class.reflect_on_association(:tickets)
      expect(association.macro).to eq(:has_many)
      expect(association.options[:dependent]).to eq(:restrict_with_error)
    end
  end

  describe "validations" do
    it "requires a filename" do
      upload = described_class.new(organization: organization, filename: nil)
      upload.valid?
      expect(upload.errors[:filename]).to include("can't be blank")
    end

    it "requires a status" do
      upload = described_class.new(organization: organization, filename: "test.csv", status: nil)
      upload.valid?
      expect(upload.errors[:status]).to include("can't be blank")
    end

    it "rejects an invalid status" do
      upload = described_class.new(organization: organization, filename: "test.csv", status: "unknown")
      upload.valid?
      expect(upload.errors[:status]).to include("is not included in the list")
    end

    %w[pending processing completed failed].each do |valid_status|
      it "accepts status '#{valid_status}'" do
        upload = described_class.new(organization: organization, filename: "test.csv", status: valid_status)
        expect(upload).to be_valid
      end
    end
  end

  describe "defaults" do
    it "defaults status to pending" do
      upload = described_class.new(organization: organization, filename: "test.csv")
      expect(upload.status).to eq("pending")
    end

    it "defaults processed_records to 0" do
      upload = described_class.create!(organization: organization, filename: "test.csv")
      expect(upload.processed_records).to eq(0)
    end

    it "defaults failed_records to 0" do
      upload = described_class.create!(organization: organization, filename: "test.csv")
      expect(upload.failed_records).to eq(0)
    end
  end

  describe "tenant isolation" do
    it "requires an organization" do
      upload = described_class.new(filename: "test.csv")
      expect(upload).not_to be_valid
      expect(upload.errors[:organization]).to include("must exist")
    end

    it "cannot be created without an organization at the database level" do
      expect {
        described_class.connection.execute(<<~SQL)
          INSERT INTO uploads (id, filename, status, created_at, updated_at)
          VALUES (gen_random_uuid(), 'test.csv', 'pending', NOW(), NOW())
        SQL
      }.to raise_error(ActiveRecord::NotNullViolation)
    end
  end

  describe "uploaded_by relationship" do
    it "can reference the uploading user" do
      upload = described_class.create!(organization: organization, filename: "test.csv", uploaded_by: user)
      expect(upload.reload.uploaded_by).to eq(user)
    end

    it "allows uploaded_by to be nil" do
      upload = described_class.create!(organization: organization, filename: "test.csv")
      expect(upload.uploaded_by).to be_nil
    end
  end

  describe "STATUSES constant" do
    it "defines exactly pending, processing, completed, failed" do
      expect(Upload::STATUSES).to eq(%w[pending processing completed failed])
    end
  end
end
