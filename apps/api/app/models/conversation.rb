# frozen_string_literal: true

class Conversation < ApplicationRecord
  belongs_to :organization
  belongs_to :user
  has_many :messages, dependent: :destroy

  validates :user, presence: true
end
