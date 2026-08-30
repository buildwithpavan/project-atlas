# frozen_string_literal: true

module Ai
  module Schemas
    class DetectedTheme < OpenAI::BaseModel
      required :title, String
      required :description, String
      required :severity, OpenAI::EnumOf[:low, :medium, :high, :critical]
      required :evidence_summary, String
      required :recommended_action, String
      required :ticket_ids, OpenAI::ArrayOf[String]
    end

    class ThemeDetectionOutput < OpenAI::BaseModel
      required :themes, OpenAI::ArrayOf[DetectedTheme]
    end
  end
end
