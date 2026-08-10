# frozen_string_literal: true

class AiAnalysis < ApplicationRecord
  STATUSES = %w[pending processing completed failed].freeze
  SENTIMENTS = %w[positive negative neutral mixed].freeze

  belongs_to :organization
  belongs_to :ticket

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :sentiment, inclusion: { in: SENTIMENTS }, allow_nil: true
  validates :confidence, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true
end
