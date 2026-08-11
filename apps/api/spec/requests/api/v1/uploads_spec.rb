# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /api/v1/uploads", type: :request do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme") }
  let(:user) do
    User.create!(email: "user@example.com", first_name: "A", last_name: "B", password: "password123")
  end
  let!(:membership) { Membership.create!(user: user, organization: organization, role: "member") }
  let(:access_token) { Identity::AccessToken.encode(user) }
  let(:headers) { { "Authorization" => "Bearer #{access_token}" } }
  let(:csv_content) { "subject,description,customer_name\nLogin bug,Cannot login,Jane\n" }
  let(:csv_file) { Rack::Test::UploadedFile.new(StringIO.new(csv_content), "text/csv", original_filename: "tickets.csv") }

  describe "authentication" do
    it "rejects unauthenticated requests" do
      post "/api/v1/uploads", params: { file: csv_file }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "authorization" do
    it "rejects users with no organization membership" do
      orphan = User.create!(email: "orphan@example.com", first_name: "O", last_name: "P", password: "password123")
      token = Identity::AccessToken.encode(orphan)
      post "/api/v1/uploads", params: { file: csv_file }, headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "file validation" do
    it "rejects missing file with HTTP 400" do
      post "/api/v1/uploads", params: {}, headers: headers
      expect(response).to have_http_status(:bad_request)
    end

    it "returns RFC 9457 Problem Details for missing file" do
      post "/api/v1/uploads", params: {}, headers: headers
      body = response.parsed_body

      expect(body["type"]).to eq("/errors/parameter-missing")
      expect(body["title"]).to eq("Bad Request")
      expect(body["status"]).to eq(400)
      expect(body["detail"]).to include("file")
    end

    it "does not expose Rails internals for missing file" do
      post "/api/v1/uploads", params: {}, headers: headers
      body = response.body

      expect(body).not_to include("ActionController")
      expect(body).not_to include("ParameterMissing")
    end

    it "rejects non-CSV file" do
      txt_file = Rack::Test::UploadedFile.new(StringIO.new("hello"), "text/plain", original_filename: "data.txt")
      post "/api/v1/uploads", params: { file: txt_file }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["detail"]).to include("Invalid file type")
    end

    it "rejects files exceeding 25MB" do
      large_file = Rack::Test::UploadedFile.new(StringIO.new("x" * (26 * 1024 * 1024)), "text/csv", original_filename: "big.csv")
      post "/api/v1/uploads", params: { file: large_file }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["detail"]).to include("File too large")
    end
  end

  describe "successful upload" do
    before do
      ActiveJob::Base.queue_adapter = :test
    end

    subject(:request) { post "/api/v1/uploads", params: { file: csv_file }, headers: headers }

    it "returns HTTP 201" do
      request
      expect(response).to have_http_status(:created)
    end

    it "creates an Upload record" do
      expect { request }.to change(Upload, :count).by(1)
    end

    it "returns upload metadata" do
      request
      data = response.parsed_body["data"]
      expect(data["id"]).to be_present
      expect(data["filename"]).to eq("tickets.csv")
      expect(data["status"]).to eq("pending")
      expect(data["created_at"]).to be_present
    end

    it "does not return CSV contents in response" do
      request
      body = response.body
      expect(body).not_to include("Login bug")
      expect(body).not_to include("Cannot login")
    end

    it "enqueues a processing job" do
      expect { request }.to have_enqueued_job(ProcessUploadJob)
    end

    it "attaches the file to the upload" do
      request
      upload = Upload.last
      expect(upload.reload.file).to be_attached
    end

    it "assigns the upload to the user's organization" do
      request
      upload = Upload.last
      expect(upload.organization_id).to eq(organization.id)
    end

    it "records the uploading user" do
      request
      upload = Upload.last
      expect(upload.uploaded_by_id).to eq(user.id)
    end
  end
end
