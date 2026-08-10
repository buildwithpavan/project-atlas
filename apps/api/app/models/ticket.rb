# frozen_string_literal: true

class Ticket < ApplicationRecord
  belongs_to :organization
  belongs_to :upload

  validates :subject, presence: true
end
