# frozen_string_literal: true

require "rails_helper"

RSpec.describe DetectThemesJob, type: :job do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme") }

  it "calls Ai::DetectThemes with the organization" do
    result = Ai::DetectThemes::Result.new(themes_created: 2, themes_updated: 1, tickets_analyzed: 10)
    allow(Ai::DetectThemes).to receive(:call).and_return(result)

    described_class.perform_now(organization.id)

    expect(Ai::DetectThemes).to have_received(:call).with(organization: organization)
  end
end
