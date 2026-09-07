# frozen_string_literal: true

class ExecutiveSummary < ApplicationRecord
  ALLOWED_PRIORITIES = %w[high medium low].freeze
  MAX_KEY_FINDINGS = 5
  MAX_ATTENTION_ITEMS = 5
  MAX_RECOMMENDED_ACTIONS = 5

  belongs_to :organization

  validates :summary, presence: true
  validates :analyzed_ticket_count, presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :generated_at, presence: true
  validate :validate_key_findings_structure
  validate :validate_attention_items_structure
  validate :validate_recommended_actions_structure

  private

  def validate_key_findings_structure
    validate_json_array(:key_findings, MAX_KEY_FINDINGS, %w[title description evidence_count])
  end

  def validate_attention_items_structure
    validate_json_array(:attention_items, MAX_ATTENTION_ITEMS, %w[title description priority evidence_count]) do |item, index|
      unless ALLOWED_PRIORITIES.include?(item["priority"])
        errors.add(:attention_items, "item #{index} has invalid priority: #{item['priority']}")
      end
    end
  end

  def validate_recommended_actions_structure
    validate_json_array(:recommended_actions, MAX_RECOMMENDED_ACTIONS, %w[title description evidence_count])
  end

  def validate_json_array(field, max_count, required_keys)
    value = send(field)
    return if value.blank?

    unless value.is_a?(Array)
      errors.add(field, "must be an array")
      return
    end

    if value.size > max_count
      errors.add(field, "exceeds maximum of #{max_count} items")
      return
    end

    value.each_with_index do |item, index|
      unless item.is_a?(Hash)
        errors.add(field, "item #{index} must be an object")
        next
      end

      required_keys.each do |key|
        errors.add(field, "item #{index} is missing required key: #{key}") unless item.key?(key)
      end

      if item.key?("evidence_count") && (!item["evidence_count"].is_a?(Integer) || item["evidence_count"] < 0)
        errors.add(field, "item #{index} has invalid evidence_count")
      end

      yield(item, index) if block_given?
    end
  end
end
