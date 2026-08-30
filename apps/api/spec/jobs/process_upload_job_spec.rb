# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProcessUploadJob, type: :job do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme") }
  let(:upload) { Upload.create!(organization: organization, filename: "test.csv") }

  before do
    upload.file.attach(
      io: StringIO.new("subject\nTest ticket\n"),
      filename: "test.csv",
      content_type: "text/csv"
    )
  end

  it "calls Tickets::ProcessCsv with the upload" do
    expect(Tickets::ProcessCsv).to receive(:call).with(upload)
    described_class.perform_now(upload)
  end

  it "does not create tickets if upload is already completed" do
    upload.update!(status: "completed")
    expect { described_class.perform_now(upload) }.not_to change(Ticket, :count)
  end

  it "processes pending uploads" do
    described_class.perform_now(upload)
    expect(upload.reload.status).to eq("completed")
    expect(Ticket.count).to eq(1)
  end

  describe "queue configuration" do
    it "uses the import queue" do
      expect(described_class.new.queue_name).to eq("import")
    end
  end
end
