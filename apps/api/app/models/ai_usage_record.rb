# frozen_string_literal: true

class AiUsageRecord < ApplicationRecord
  OPERATIONS = %w[chat embedding].freeze
  PROVIDERS = %w[openai].freeze

  belongs_to :organization
  belongs_to :user
  belongs_to :conversation
  belongs_to :message, optional: true

  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :model, presence: true
  validates :operation, presence: true, inclusion: { in: OPERATIONS }
  validates :prompt_tokens, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :completion_tokens, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total_tokens, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :estimated_cost, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
