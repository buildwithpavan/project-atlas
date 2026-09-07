# frozen_string_literal: true

class Ticket < ApplicationRecord
  belongs_to :organization
  belongs_to :upload
  has_one :ai_analysis, dependent: :destroy
  has_many :theme_memberships, dependent: :destroy
  has_many :themes, through: :theme_memberships

  validates :subject, presence: true
end
