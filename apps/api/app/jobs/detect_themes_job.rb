# frozen_string_literal: true

class DetectThemesJob < ApplicationJob
  queue_as :default

  def perform(organization_id)
    organization = Organization.find(organization_id)
    result = Ai::DetectThemes.call(organization: organization)

    Rails.logger.info(
      "[DetectThemesJob] organization_id=#{organization_id} " \
      "themes_created=#{result.themes_created} " \
      "themes_updated=#{result.themes_updated} " \
      "tickets_analyzed=#{result.tickets_analyzed}"
    )
  end
end
