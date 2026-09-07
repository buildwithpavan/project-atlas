# frozen_string_literal: true

class Document < ApplicationRecord
  STATUSES = %w[pending processing completed failed].freeze

  belongs_to :organization
  belongs_to :uploaded_by, class_name: "User", optional: true
  has_many :document_chunks, dependent: :destroy
  has_one_attached :file

  validates :title, presence: true
  validates :filename, presence: true
  validates :content_type, presence: true
  validates :file_size, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :checksum, uniqueness: { scope: :organization_id }, allow_nil: true
end
