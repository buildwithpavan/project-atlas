# frozen_string_literal: true

class Message < ApplicationRecord
  ROLES = %w[user assistant].freeze

  belongs_to :organization
  belongs_to :conversation

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :content, presence: true, length: { maximum: 50_000 }
  validates :position, presence: true, uniqueness: { scope: :conversation_id }
end
