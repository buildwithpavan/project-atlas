# frozen_string_literal: true

require "rails_helper"

RSpec.describe Conversation, type: :model do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme") }
  let(:user) { User.create!(email: "user@example.com", first_name: "A", last_name: "B", password: "password123") }

  describe "associations" do
    it "belongs to organization" do
      association = described_class.reflect_on_association(:organization)
      expect(association.macro).to eq(:belongs_to)
    end

    it "belongs to user" do
      association = described_class.reflect_on_association(:user)
      expect(association.macro).to eq(:belongs_to)
    end

    it "has many messages" do
      association = described_class.reflect_on_association(:messages)
      expect(association.macro).to eq(:has_many)
      expect(association.options[:dependent]).to eq(:destroy)
    end
  end

  describe "validations" do
    it "requires a user" do
      conversation = described_class.new(organization: organization)
      expect(conversation).not_to be_valid
      expect(conversation.errors[:user]).to include("must exist")
    end
  end

  describe "defaults" do
    it "allows nil title" do
      conversation = described_class.create!(organization: organization, user: user)
      expect(conversation.title).to be_nil
    end
  end

  describe "tenant isolation" do
    it "requires an organization" do
      conversation = described_class.new(user: user)
      expect(conversation).not_to be_valid
      expect(conversation.errors[:organization]).to include("must exist")
    end

    it "cannot be created without an organization at the database level" do
      expect {
        described_class.connection.execute(<<~SQL)
          INSERT INTO conversations (id, user_id, created_at, updated_at)
          VALUES (gen_random_uuid(), '#{user.id}', NOW(), NOW())
        SQL
      }.to raise_error(ActiveRecord::NotNullViolation)
    end
  end
end
