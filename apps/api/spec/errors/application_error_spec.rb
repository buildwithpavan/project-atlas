# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationError do
  describe NotFoundError do
    subject(:error) { described_class.new }

    it "exposes Problem Details attributes" do
      expect(error.status).to eq(:not_found)
      expect(error.type).to eq("/errors/not-found")
      expect(error.title).to eq("Resource Not Found")
      expect(error.detail).to eq("Resource not found")
    end
  end

  describe UnauthorizedError do
    subject(:error) { described_class.new }

    it "exposes Problem Details attributes" do
      expect(error.status).to eq(:unauthorized)
      expect(error.type).to eq("/errors/unauthorized")
      expect(error.title).to eq("Unauthorized")
      expect(error.detail).to eq("Unauthorized")
    end
  end

  describe ValidationError do
    subject(:error) { described_class.new }

    it "exposes Problem Details attributes" do
      expect(error.status).to eq(:unprocessable_entity)
      expect(error.type).to eq("/errors/validation")
      expect(error.title).to eq("Validation Error")
      expect(error.detail).to eq("Validation failed")
    end

    it "exposes validation errors when provided" do
      errors = { email: ["has already been taken"] }
      error = described_class.new(errors: errors)

      expect(error.errors).to eq(errors)
    end
  end
end
