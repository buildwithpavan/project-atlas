# frozen_string_literal: true

class Theme < ApplicationRecord
  STATUSES = %w[active resolved archived].freeze
  SEVERITIES = %w[low medium high critical].freeze

  belongs_to :organization
  has_many :theme_memberships, dependent: :destroy
  has_many :tickets, through: :theme_memberships

  validates :title, presence: true
  validates :description, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :severity, presence: true, inclusion: { in: SEVERITIES }
  validates :ticket_count, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(status: "active") }
  scope :by_severity, ->(severity) { where(severity: severity) }
  scope :by_ticket_count, -> { order(ticket_count: :desc) }
  scope :recent, -> { order(last_seen_at: :desc) }
end
