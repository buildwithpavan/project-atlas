# frozen_string_literal: true

class Ticket < ApplicationRecord
  belongs_to :organization
  belongs_to :upload
  has_one :ai_analysis, dependent: :destroy

  validates :subject, presence: true
end
