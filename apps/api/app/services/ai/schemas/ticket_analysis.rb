# frozen_string_literal: true

module Ai
  module Schemas
    class TicketAnalysis < OpenAI::BaseModel
      required :sentiment, OpenAI::EnumOf[:positive, :negative, :neutral, :mixed]
      required :summary, String
      required :category, String
      required :confidence, Float
      required :feature_request, OpenAI::Boolean
      required :bug_report, OpenAI::Boolean
      required :knowledge_gap, OpenAI::Boolean
    end
  end
end
