# frozen_string_literal: true

class Membership < ApplicationRecord
  ROLES = %w[owner admin member viewer].freeze

  belongs_to :user
  belongs_to :organization

  validates :role, presence: true, inclusion: { in: ROLES }
end
