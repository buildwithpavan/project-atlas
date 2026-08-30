# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tickets::ProcessCsv, type: :service do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme") }
  let(:upload) { Upload.create!(organization: organization, filename: "test.csv") }

  def attach_csv(upload, content)
    upload.file.attach(
      io: StringIO.new(content),
      filename: upload.filename,
      content_type: "text/csv"
    )
  end

  describe "successful processing" do
    let(:csv_content) do
      <<~CSV
        subject,description,customer_name,customer_email,priority,status,category
        Login issue,Cannot login to dashboard,Jane Doe,jane@example.com,high,open,authentication
        Slow page,Dashboard loads slowly,John Smith,john@example.com,low,open,performance
      CSV
    end

    before { attach_csv(upload, csv_content) }

    it "transitions upload to processing then completed" do
      described_class.call(upload)
      upload.reload
      expect(upload.status).to eq("completed")
    end

    it "creates ticket records" do
      expect { described_class.call(upload) }.to change(Ticket, :count).by(2)
    end

    it "sets ticket organization_id from upload" do
      described_class.call(upload)
      Ticket.where(upload: upload).each do |ticket|
        expect(ticket.organization_id).to eq(upload.organization_id)
      end
    end

    it "sets ticket upload_id" do
      described_class.call(upload)
      Ticket.where(upload: upload).each do |ticket|
        expect(ticket.upload_id).to eq(upload.id)
      end
    end

    it "maps CSV columns to ticket fields" do
      described_class.call(upload)
      ticket = Ticket.find_by(subject: "Login issue")
      expect(ticket.description).to eq("Cannot login to dashboard")
      expect(ticket.customer_name).to eq("Jane Doe")
      expect(ticket.customer_email).to eq("jane@example.com")
      expect(ticket.priority).to eq("high")
      expect(ticket.status).to eq("open")
      expect(ticket.category).to eq("authentication")
    end

    it "updates processed_records count" do
      described_class.call(upload)
      expect(upload.reload.processed_records).to eq(2)
    end

    it "sets total_records" do
      described_class.call(upload)
      expect(upload.reload.total_records).to eq(2)
    end
  end

  describe "resilient ingestion" do
    let(:csv_content) do
      <<~CSV
        subject,description
        Valid ticket,Has a subject
        ,Missing subject - should fail
        Another valid,Also has subject
      CSV
    end

    before { attach_csv(upload, csv_content) }

    it "persists valid rows and skips invalid rows" do
      described_class.call(upload)
      expect(Ticket.count).to eq(2)
    end

    it "increments failed_records for invalid rows" do
      described_class.call(upload)
      expect(upload.reload.failed_records).to eq(1)
    end

    it "still completes the upload" do
      described_class.call(upload)
      expect(upload.reload.status).to eq("completed")
    end
  end

  describe "malformed CSV" do
    before { attach_csv(upload, "subject\n\"unclosed quote") }

    it "marks upload as failed" do
      described_class.call(upload)
      expect(upload.reload.status).to eq("failed")
    end

    it "stores an error message" do
      described_class.call(upload)
      expect(upload.reload.error_message).to be_present
    end
  end

  describe "missing required headers" do
    before { attach_csv(upload, "description,customer_name\nSome desc,John\n") }

    it "marks upload as failed" do
      described_class.call(upload)
      expect(upload.reload.status).to eq("failed")
    end

    it "includes missing column in error message" do
      described_class.call(upload)
      expect(upload.reload.error_message).to include("subject")
    end
  end

  describe "unexpected exception" do
    before { attach_csv(upload, "subject\nTest\n") }

    it "marks upload as failed on unexpected error" do
      allow(Ticket).to receive(:insert_all).and_raise(RuntimeError, "unexpected")
      described_class.call(upload)
      expect(upload.reload.status).to eq("failed")
      expect(upload.reload.error_message).to include("unexpected")
    end
  end

  describe "tenant integrity" do
    let(:other_org) { Organization.create!(name: "Other", slug: "other") }
    let(:csv_content) { "subject\nTest ticket\n" }

    before { attach_csv(upload, csv_content) }

    it "assigns all tickets to the upload's organization, not another" do
      described_class.call(upload)
      ticket = Ticket.last
      expect(ticket.organization_id).to eq(organization.id)
      expect(ticket.organization_id).not_to eq(other_org.id)
    end
  end

  describe "atomic claim" do
    let(:csv_content) { "subject\nTest\n" }
    before { attach_csv(upload, csv_content) }

    it "claims a pending upload and transitions to processing" do
      described_class.call(upload)
      # After full processing it ends up completed, but we can verify it was claimed
      expect(upload.reload.status).to eq("completed")
    end

    it "does not process an already-processing upload" do
      upload.update!(status: "processing")
      expect { described_class.call(upload) }.not_to change(Ticket, :count)
    end

    it "does not process a completed upload" do
      upload.update!(status: "completed")
      expect { described_class.call(upload) }.not_to change(Ticket, :count)
    end

    it "does not process a failed upload" do
      upload.update!(status: "failed")
      expect { described_class.call(upload) }.not_to change(Ticket, :count)
    end

    it "prevents a second claim via atomic UPDATE" do
      # Simulate first worker claiming
      rows_affected = Upload.where(id: upload.id, status: "pending")
                            .update_all(status: "processing", updated_at: Time.current)
      expect(rows_affected).to eq(1)

      # Second worker attempts to claim the same upload
      rows_affected_2 = Upload.where(id: upload.id, status: "pending")
                              .update_all(status: "processing", updated_at: Time.current)
      expect(rows_affected_2).to eq(0)
    end

    it "allows normal processing after successful claim" do
      described_class.call(upload)
      expect(Ticket.count).to eq(1)
      expect(upload.reload.processed_records).to eq(1)
    end
  end

  describe "batching" do
    let(:csv_content) do
      header = "subject\n"
      rows = 50.times.map { |i| "Ticket #{i}\n" }.join
      header + rows
    end

    before { attach_csv(upload, csv_content) }

    it "processes all rows" do
      described_class.call(upload)
      expect(Ticket.count).to eq(50)
      expect(upload.reload.processed_records).to eq(50)
    end
  end

  describe "AI analysis pipeline" do
    before do
      ActiveJob::Base.queue_adapter = :test
    end

    describe "successful row creates analysis" do
      let(:csv_content) do
        <<~CSV
          subject,description
          Login issue,Cannot login
          Slow page,Dashboard loads slowly
        CSV
      end

      before { attach_csv(upload, csv_content) }

      it "creates one AiAnalysis per ticket" do
        expect { described_class.call(upload) }.to change(AiAnalysis, :count).by(2)
      end

      it "creates AiAnalysis belonging to the same organization as the ticket" do
        described_class.call(upload)
        Ticket.where(upload: upload).each do |ticket|
          analysis = ticket.ai_analysis
          expect(analysis).to be_present
          expect(analysis.organization_id).to eq(ticket.organization_id)
        end
      end

      it "creates AiAnalysis in pending status" do
        described_class.call(upload)
        AiAnalysis.all.each do |analysis|
          expect(analysis.status).to eq("pending")
        end
      end

      it "enqueues AnalyzeTicketJob for each analysis" do
        described_class.call(upload)
        analyses = AiAnalysis.all
        expect(AnalyzeTicketJob).to have_been_enqueued.exactly(2).times
        analyses.each do |analysis|
          expect(AnalyzeTicketJob).to have_been_enqueued.with(analysis.id)
        end
      end
    end

    describe "invalid rows do not create analyses" do
      let(:csv_content) do
        <<~CSV
          subject,description
          Valid ticket,Has a subject
          ,Missing subject
        CSV
      end

      before { attach_csv(upload, csv_content) }

      it "creates analysis only for valid tickets" do
        described_class.call(upload)
        expect(Ticket.count).to eq(1)
        expect(AiAnalysis.count).to eq(1)
      end

      it "does not enqueue jobs for invalid rows" do
        described_class.call(upload)
        expect(AnalyzeTicketJob).to have_been_enqueued.exactly(1).times
      end
    end

    describe "duplicate/retry safety" do
      let(:csv_content) { "subject\nTest ticket\n" }
      before { attach_csv(upload, csv_content) }

      it "does not create duplicate analyses if upload is reprocessed" do
        described_class.call(upload)
        expect(AiAnalysis.count).to eq(1)

        # Second attempt: upload is already completed, claim fails
        described_class.call(upload)
        expect(AiAnalysis.count).to eq(1)
      end
    end

    describe "transactional integrity" do
      let(:csv_content) { "subject\nTest ticket\n" }
      before { attach_csv(upload, csv_content) }

      it "does not create tickets without analyses if analysis insert fails" do
        allow(AiAnalysis).to receive(:insert_all).and_raise(ActiveRecord::RecordNotUnique, "duplicate")
        described_class.call(upload)
        expect(Ticket.count).to eq(0)
        expect(AiAnalysis.count).to eq(0)
        expect(upload.reload.status).to eq("failed")
      end

      it "does not enqueue jobs if the transaction rolls back" do
        allow(AiAnalysis).to receive(:insert_all).and_raise(ActiveRecord::RecordNotUnique, "duplicate")
        described_class.call(upload)
        expect(AnalyzeTicketJob).not_to have_been_enqueued
      end
    end
  end

  describe "row count limit" do
    before do
      ActiveJob::Base.queue_adapter = :test
      stub_const("Tickets::ProcessCsv::MAX_ROW_COUNT", 5)
    end

    context "under limit" do
      let(:csv_content) do
        header = "subject\n"
        rows = 3.times.map { |i| "Ticket #{i}\n" }.join
        header + rows
      end

      before { attach_csv(upload, csv_content) }

      it "processes successfully" do
        described_class.call(upload)
        expect(upload.reload.status).to eq("completed")
        expect(Ticket.count).to eq(3)
      end
    end

    context "at limit" do
      let(:csv_content) do
        header = "subject\n"
        rows = 5.times.map { |i| "Ticket #{i}\n" }.join
        header + rows
      end

      before { attach_csv(upload, csv_content) }

      it "processes successfully" do
        described_class.call(upload)
        expect(upload.reload.status).to eq("completed")
        expect(Ticket.count).to eq(5)
      end
    end

    context "over limit" do
      let(:csv_content) do
        header = "subject\n"
        rows = 6.times.map { |i| "Ticket #{i}\n" }.join
        header + rows
      end

      before { attach_csv(upload, csv_content) }

      it "fails the upload" do
        described_class.call(upload)
        expect(upload.reload.status).to eq("failed")
      end

      it "stores a descriptive error message" do
        described_class.call(upload)
        expect(upload.reload.error_message).to include("exceeds the maximum")
        expect(upload.reload.error_message).to include("6")
        expect(upload.reload.error_message).to include("5")
      end

      it "does not create any tickets" do
        described_class.call(upload)
        expect(Ticket.count).to eq(0)
      end

      it "does not create any AI analyses" do
        described_class.call(upload)
        expect(AiAnalysis.count).to eq(0)
      end

      it "does not enqueue any jobs" do
        described_class.call(upload)
        expect(AnalyzeTicketJob).not_to have_been_enqueued
      end
    end
  end
end
