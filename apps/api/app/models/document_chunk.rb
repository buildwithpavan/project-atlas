# frozen_string_literal: true

class DocumentChunk < ApplicationRecord
  belongs_to :organization
  belongs_to :document

  validates :content, presence: true
  validates :position, presence: true, uniqueness: { scope: :document_id }
end
