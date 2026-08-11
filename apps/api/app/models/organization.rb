# frozen_string_literal: true

class Organization < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :uploads, dependent: :destroy
  has_many :tickets, dependent: :destroy
  has_many :ai_analyses, dependent: :destroy
  has_many :reports, dependent: :destroy
  has_many :knowledge_suggestions, dependent: :destroy
  has_one :executive_summary, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true
end
