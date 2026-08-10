# frozen_string_literal: true

class Upload < ApplicationRecord
  STATUSES = %w[pending processing completed failed].freeze

  belongs_to :organization
  belongs_to :uploaded_by, class_name: "User", optional: true
  has_many :tickets, dependent: :restrict_with_error

  validates :filename, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
end
