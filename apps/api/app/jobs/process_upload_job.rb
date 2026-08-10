# frozen_string_literal: true

class ProcessUploadJob < ApplicationJob
  queue_as :default

  def perform(upload)
    Tickets::ProcessCsv.call(upload)
  end
end
