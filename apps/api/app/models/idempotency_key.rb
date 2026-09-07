# frozen_string_literal: true

class IdempotencyKey < ApplicationRecord
  belongs_to :organization
  belongs_to :user
  belongs_to :conversation
  belongs_to :user_message, class_name: "Message", optional: true
  belongs_to :assistant_message, class_name: "Message", optional: true

  validates :key, presence: true, uniqueness: { scope: %i[organization_id user_id conversation_id] }
  validates :request_fingerprint, presence: true
  validates :conversation_id, presence: true
end
