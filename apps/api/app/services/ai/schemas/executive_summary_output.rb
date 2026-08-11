# frozen_string_literal: true

module Ai
  module Schemas
    class KeyFinding < OpenAI::BaseModel
      required :title, String
      required :description, String
      required :evidence_count, Integer
      required :category, String, nil?: true
    end

    class AttentionItem < OpenAI::BaseModel
      required :title, String
      required :description, String
      required :priority, OpenAI::EnumOf[:high, :medium, :low]
      required :evidence_count, Integer
    end

    class RecommendedAction < OpenAI::BaseModel
      required :title, String
      required :description, String
      required :evidence_count, Integer
    end

    class ExecutiveSummaryOutput < OpenAI::BaseModel
      required :summary, String
      required :key_findings, OpenAI::ArrayOf[KeyFinding]
      required :attention_items, OpenAI::ArrayOf[AttentionItem]
      required :recommended_actions, OpenAI::ArrayOf[RecommendedAction]
    end
  end
end
