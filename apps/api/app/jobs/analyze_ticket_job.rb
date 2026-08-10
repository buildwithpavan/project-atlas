# frozen_string_literal: true

class AnalyzeTicketJob < ApplicationJob
  queue_as :default

  def perform(ai_analysis)
    Ai::AnalyzeTicket.call(ai_analysis)
  end
end
