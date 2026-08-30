# frozen_string_literal: true

class ThemeMembership < ApplicationRecord
  belongs_to :theme
  belongs_to :ticket
  belongs_to :organization

  validates :theme_id, uniqueness: { scope: :ticket_id }
  validates :relevance_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true
end
