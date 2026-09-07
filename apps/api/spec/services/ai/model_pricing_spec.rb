# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::ModelPricing, type: :service do
  describe ".estimate" do
    it "calculates cost for a known model" do
      cost = described_class.estimate(model: "gpt-5.6-luna", prompt_tokens: 1000, completion_tokens: 500)
      # 1000 * 0.000005 + 500 * 0.000015 = 0.005 + 0.0075 = 0.0125
      expect(cost).to eq(0.0125)
    end

    it "calculates input token cost" do
      cost = described_class.estimate(model: "gpt-5.6-luna", prompt_tokens: 1000, completion_tokens: 0)
      expect(cost).to eq(0.005)
    end

    it "calculates output token cost" do
      cost = described_class.estimate(model: "gpt-5.6-luna", prompt_tokens: 0, completion_tokens: 1000)
      expect(cost).to eq(0.015)
    end

    it "returns zero for zero usage" do
      cost = described_class.estimate(model: "gpt-5.6-luna", prompt_tokens: 0, completion_tokens: 0)
      expect(cost).to eq(0.0)
    end

    it "handles nil token values" do
      cost = described_class.estimate(model: "gpt-5.6-luna", prompt_tokens: nil, completion_tokens: nil)
      expect(cost).to eq(0.0)
    end

    it "returns zero for unknown model" do
      cost = described_class.estimate(model: "unknown-model", prompt_tokens: 1000, completion_tokens: 500)
      expect(cost).to eq(0.0)
    end

    it "logs a warning for unknown models" do
      allow(Rails.logger).to receive(:warn)
      described_class.estimate(model: "future-model-x", prompt_tokens: 100)
      expect(Rails.logger).to have_received(:warn).with(/\[ModelPricing\] Unknown model 'future-model-x'/)
    end

    it "does not log a warning for known models" do
      allow(Rails.logger).to receive(:warn)
      described_class.estimate(model: "gpt-5.6-luna", prompt_tokens: 100)
      expect(Rails.logger).not_to have_received(:warn)
    end

    it "maintains decimal precision" do
      cost = described_class.estimate(model: "text-embedding-3-small", prompt_tokens: 1)
      # 1 * 0.00000002 = 0.00000002, rounded to 6 places = 0.0
      expect(cost).to eq(0.0)
    end

    it "calculates embedding model cost" do
      cost = described_class.estimate(model: "text-embedding-3-small", prompt_tokens: 100_000)
      # 100000 * 0.00000002 = 0.002
      expect(cost).to eq(0.002)
    end

    it "calculates gpt-4o cost" do
      cost = described_class.estimate(model: "gpt-4o", prompt_tokens: 1000, completion_tokens: 1000)
      # 1000 * 0.0000025 + 1000 * 0.000010 = 0.0025 + 0.01 = 0.0125
      expect(cost).to eq(0.0125)
    end

    it "calculates gpt-4o-mini cost" do
      cost = described_class.estimate(model: "gpt-4o-mini", prompt_tokens: 1000, completion_tokens: 1000)
      # 1000 * 0.00000015 + 1000 * 0.0000006 = 0.00015 + 0.0006 = 0.00075
      expect(cost).to eq(0.00075)
    end

    it "defaults to zero completion_tokens" do
      cost = described_class.estimate(model: "gpt-5.6-luna", prompt_tokens: 1000)
      expect(cost).to eq(0.005)
    end
  end

  describe ".supported_model?" do
    it "returns true for known models" do
      expect(described_class.supported_model?("gpt-5.6-luna")).to be true
      expect(described_class.supported_model?("gpt-4o")).to be true
      expect(described_class.supported_model?("text-embedding-3-small")).to be true
    end

    it "returns false for unknown models" do
      expect(described_class.supported_model?("unknown")).to be false
    end
  end

  describe ".supported_models" do
    it "returns all known model names" do
      models = described_class.supported_models
      expect(models).to include("gpt-5.6-luna", "gpt-4o", "gpt-4o-mini", "text-embedding-3-small")
    end
  end
end
