# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Documents API", type: :request do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme") }
  let(:other_org) { Organization.create!(name: "Other", slug: "other") }
  let(:user) do
    User.create!(email: "user@example.com", first_name: "A", last_name: "B", password: "password123")
  end
  let(:other_user) do
    User.create!(email: "other@example.com", first_name: "C", last_name: "D", password: "password123")
  end
  let!(:membership) { Membership.create!(user: user, organization: organization, role: "member") }
  let(:access_token) { Identity::AccessToken.encode(user) }
  let(:headers) { { "Authorization" => "Bearer #{access_token}" } }

  let(:pdf_file) do
    Rack::Test::UploadedFile.new(
      StringIO.new("dummy pdf content"),
      "application/pdf",
      original_filename: "guide.pdf"
    )
  end
  let(:txt_file) do
    Rack::Test::UploadedFile.new(
      StringIO.new("Hello world"),
      "text/plain",
      original_filename: "notes.txt"
    )
  end
  let(:md_file) do
    Rack::Test::UploadedFile.new(
      StringIO.new("# Title\nContent"),
      "text/markdown",
      original_filename: "readme.md"
    )
  end
  let(:csv_file) do
    Rack::Test::UploadedFile.new(
      StringIO.new("name,value\nAlice,42\n"),
      "text/csv",
      original_filename: "data.csv"
    )
  end

  def create_document(org: organization, attrs: {})
    doc = Document.create!(
      {
        organization: org,
        title: "Test Doc",
        filename: "test.pdf",
        content_type: "application/pdf",
        file_size: 1024,
        uploaded_by: user
      }.merge(attrs)
    )
    doc.file.attach(
      io: StringIO.new("file content"),
      filename: doc.filename,
      content_type: doc.content_type
    )
    doc
  end

  # ── POST /api/v1/documents ──────────────────────────────────────────

  describe "POST /api/v1/documents" do
    describe "authentication" do
      it "rejects unauthenticated requests" do
        post "/api/v1/documents", params: { file: pdf_file }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe "authorization" do
      it "rejects users with no organization membership" do
        orphan = User.create!(email: "orphan@example.com", first_name: "O", last_name: "P", password: "password123")
        token = Identity::AccessToken.encode(orphan)
        post "/api/v1/documents", params: { file: pdf_file }, headers: { "Authorization" => "Bearer #{token}" }
        expect(response).to have_http_status(:unauthorized)
      end

      it "rejects viewers from uploading" do
        membership.update!(role: "viewer")
        post "/api/v1/documents", params: { file: pdf_file }, headers: headers
        expect(response).to have_http_status(:forbidden)
      end

      it "allows members to upload" do
        post "/api/v1/documents", params: { file: pdf_file }, headers: headers
        expect(response).to have_http_status(:created)
      end

      it "allows admins to upload" do
        membership.update!(role: "admin")
        post "/api/v1/documents", params: { file: pdf_file }, headers: headers
        expect(response).to have_http_status(:created)
      end
    end

    describe "file validation" do
      it "rejects missing file" do
        post "/api/v1/documents", params: {}, headers: headers
        expect(response).to have_http_status(:bad_request)
      end

      it "rejects unsupported content types" do
        exe_file = Rack::Test::UploadedFile.new(
          StringIO.new("binary"),
          "application/octet-stream",
          original_filename: "app.exe"
        )
        post "/api/v1/documents", params: { file: exe_file }, headers: headers
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["detail"]).to include("Unsupported file type")
      end

      it "rejects files exceeding 50MB" do
        large_file = Rack::Test::UploadedFile.new(
          StringIO.new("x" * (51 * 1024 * 1024)),
          "application/pdf",
          original_filename: "huge.pdf"
        )
        post "/api/v1/documents", params: { file: large_file }, headers: headers
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["detail"]).to include("File too large")
      end

      it "accepts PDF files" do
        post "/api/v1/documents", params: { file: pdf_file }, headers: headers
        expect(response).to have_http_status(:created)
      end

      it "accepts TXT files" do
        post "/api/v1/documents", params: { file: txt_file }, headers: headers
        expect(response).to have_http_status(:created)
      end

      it "accepts Markdown files" do
        post "/api/v1/documents", params: { file: md_file }, headers: headers
        expect(response).to have_http_status(:created)
      end

      it "accepts CSV files" do
        post "/api/v1/documents", params: { file: csv_file }, headers: headers
        expect(response).to have_http_status(:created)
      end
    end

    describe "successful upload" do
      before { ActiveJob::Base.queue_adapter = :test }

      it "creates a Document record" do
        expect {
          post "/api/v1/documents", params: { file: txt_file }, headers: headers
        }.to change(Document, :count).by(1)
      end

      it "returns document metadata" do
        post "/api/v1/documents", params: { file: txt_file }, headers: headers
        data = response.parsed_body["data"]
        expect(data["id"]).to be_present
        expect(data["filename"]).to eq("notes.txt")
        expect(data["content_type"]).to eq("text/plain")
        expect(data["status"]).to eq("pending")
        expect(data["checksum"]).to be_present
        expect(data["chunk_count"]).to eq(0)
        expect(data["created_at"]).to be_present
        expect(data["updated_at"]).to be_present
      end

      it "attaches the file via Active Storage" do
        post "/api/v1/documents", params: { file: txt_file }, headers: headers
        doc = Document.last
        expect(doc.file).to be_attached
      end

      it "assigns the document to the user's organization" do
        post "/api/v1/documents", params: { file: txt_file }, headers: headers
        doc = Document.last
        expect(doc.organization_id).to eq(organization.id)
      end

      it "records the uploading user" do
        post "/api/v1/documents", params: { file: txt_file }, headers: headers
        doc = Document.last
        expect(doc.uploaded_by_id).to eq(user.id)
      end

      it "uses the filename as title when no title is provided" do
        post "/api/v1/documents", params: { file: txt_file }, headers: headers
        data = response.parsed_body["data"]
        expect(data["title"]).to eq("notes.txt")
      end

      it "uses the provided title when given" do
        post "/api/v1/documents", params: { file: txt_file, title: "My Notes" }, headers: headers
        data = response.parsed_body["data"]
        expect(data["title"]).to eq("My Notes")
      end

      it "computes SHA256 checksum" do
        post "/api/v1/documents", params: { file: txt_file }, headers: headers
        doc = Document.last
        expected_checksum = Digest::SHA256.hexdigest("Hello world")
        expect(doc.checksum).to eq(expected_checksum)
      end

      it "does not expose extracted_text in response" do
        post "/api/v1/documents", params: { file: txt_file }, headers: headers
        data = response.parsed_body["data"]
        expect(data).not_to have_key("extracted_text")
      end

      it "does not expose raw storage paths" do
        post "/api/v1/documents", params: { file: txt_file }, headers: headers
        body = response.body
        expect(body).not_to include("storage")
        expect(body).not_to include("blob")
      end

      it "includes uploaded_by in response" do
        post "/api/v1/documents", params: { file: txt_file }, headers: headers
        uploaded_by = response.parsed_body["data"]["uploaded_by"]
        expect(uploaded_by["id"]).to eq(user.id)
        expect(uploaded_by["email"]).to eq("user@example.com")
      end

      it "enqueues a ProcessDocumentJob" do
        expect {
          post "/api/v1/documents", params: { file: txt_file }, headers: headers
        }.to have_enqueued_job(ProcessDocumentJob)
      end
    end

    describe "duplicate checksum" do
      it "rejects duplicate checksum within same organization" do
        post "/api/v1/documents", params: { file: txt_file }, headers: headers
        expect(response).to have_http_status(:created)

        duplicate = Rack::Test::UploadedFile.new(
          StringIO.new("Hello world"),
          "text/plain",
          original_filename: "notes_copy.txt"
        )
        post "/api/v1/documents", params: { file: duplicate }, headers: headers
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["detail"]).to include("Duplicate document")
      end

      it "allows same checksum in different organizations" do
        post "/api/v1/documents", params: { file: txt_file }, headers: headers
        expect(response).to have_http_status(:created)

        Membership.create!(user: other_user, organization: other_org, role: "member")
        other_token = Identity::AccessToken.encode(other_user)
        other_headers = { "Authorization" => "Bearer #{other_token}" }

        same_file = Rack::Test::UploadedFile.new(
          StringIO.new("Hello world"),
          "text/plain",
          original_filename: "notes.txt"
        )
        post "/api/v1/documents", params: { file: same_file }, headers: other_headers
        expect(response).to have_http_status(:created)
      end
    end
  end

  # ── GET /api/v1/documents ───────────────────────────────────────────

  describe "GET /api/v1/documents" do
    describe "authentication" do
      it "rejects unauthenticated requests" do
        get "/api/v1/documents"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe "authorization" do
      it "allows viewers to list documents" do
        membership.update!(role: "viewer")
        get "/api/v1/documents", headers: headers
        expect(response).to have_http_status(:ok)
      end
    end

    describe "tenant isolation" do
      before do
        create_document(org: organization, attrs: { title: "Our doc" })
        create_document(org: other_org, attrs: { title: "Their doc" })
      end

      it "only returns documents belonging to the user's organization" do
        get "/api/v1/documents", headers: headers
        data = response.parsed_body["data"]
        expect(data.length).to eq(1)
        expect(data.first["title"]).to eq("Our doc")
      end
    end

    describe "ordering" do
      it "returns documents in reverse chronological order" do
        d1 = create_document(attrs: { title: "First" })
        d2 = create_document(attrs: { title: "Second", checksum: "different" })
        get "/api/v1/documents", headers: headers
        data = response.parsed_body["data"]
        expect(data.first["id"]).to eq(d2.id)
        expect(data.last["id"]).to eq(d1.id)
      end
    end

    describe "pagination" do
      before do
        30.times { |i| create_document(attrs: { title: "Doc #{i}", checksum: "checksum_#{i}" }) }
      end

      it "returns 25 results per page by default" do
        get "/api/v1/documents", headers: headers
        expect(response.parsed_body["data"].length).to eq(25)
      end

      it "includes pagination meta" do
        get "/api/v1/documents", headers: headers
        meta = response.parsed_body["meta"]
        expect(meta["page"]).to eq(1)
        expect(meta["per_page"]).to eq(25)
        expect(meta["total"]).to eq(30)
        expect(meta["total_pages"]).to eq(2)
      end

      it "supports custom page and per_page" do
        get "/api/v1/documents", params: { page: 2, per_page: 10 }, headers: headers
        expect(response.parsed_body["data"].length).to eq(10)
        expect(response.parsed_body["meta"]["page"]).to eq(2)
      end

      it "caps per_page at 100" do
        get "/api/v1/documents", params: { per_page: 200 }, headers: headers
        expect(response.parsed_body["meta"]["per_page"]).to eq(100)
      end
    end

    describe "response shape" do
      before { create_document }

      it "returns expected fields" do
        get "/api/v1/documents", headers: headers
        doc = response.parsed_body["data"].first
        expect(doc.keys).to contain_exactly(
          "id", "title", "filename", "content_type", "file_size",
          "status", "error_message", "checksum", "chunk_count",
          "uploaded_by", "created_at", "updated_at"
        )
      end

      it "includes uploaded_by details without N+1 queries" do
        create_document(attrs: { title: "Second", checksum: "other" })
        get "/api/v1/documents", headers: headers
        docs = response.parsed_body["data"]
        expect(docs.length).to eq(2)
        docs.each do |doc|
          expect(doc["uploaded_by"]).to include("id", "email", "first_name", "last_name")
        end
      end
    end
  end

  # ── GET /api/v1/documents/:id ───────────────────────────────────────

  describe "GET /api/v1/documents/:id" do
    let!(:document) { create_document }

    describe "authentication" do
      it "rejects unauthenticated requests" do
        get "/api/v1/documents/#{document.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe "tenant isolation" do
      let(:other_document) { create_document(org: other_org, attrs: { title: "Secret" }) }

      it "returns 404 for documents belonging to another organization" do
        get "/api/v1/documents/#{other_document.id}", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    describe "not found" do
      it "returns 404 for non-existent document" do
        get "/api/v1/documents/#{SecureRandom.uuid}", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    describe "successful response" do
      it "returns the document detail" do
        get "/api/v1/documents/#{document.id}", headers: headers
        expect(response).to have_http_status(:ok)
        data = response.parsed_body["data"]
        expect(data["id"]).to eq(document.id)
        expect(data["title"]).to eq("Test Doc")
        expect(data["filename"]).to eq("test.pdf")
      end
    end
  end

  # ── DELETE /api/v1/documents/:id ────────────────────────────────────

  describe "DELETE /api/v1/documents/:id" do
    let!(:document) { create_document }

    describe "authentication" do
      it "rejects unauthenticated requests" do
        delete "/api/v1/documents/#{document.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe "authorization" do
      it "rejects viewers from deleting" do
        membership.update!(role: "viewer")
        delete "/api/v1/documents/#{document.id}", headers: headers
        expect(response).to have_http_status(:forbidden)
      end

      it "rejects members from deleting" do
        delete "/api/v1/documents/#{document.id}", headers: headers
        expect(response).to have_http_status(:forbidden)
      end

      it "allows admins to delete" do
        membership.update!(role: "admin")
        delete "/api/v1/documents/#{document.id}", headers: headers
        expect(response).to have_http_status(:no_content)
      end

      it "allows owners to delete" do
        membership.update!(role: "owner")
        delete "/api/v1/documents/#{document.id}", headers: headers
        expect(response).to have_http_status(:no_content)
      end
    end

    describe "tenant isolation" do
      let(:other_document) { create_document(org: other_org, attrs: { title: "Secret" }) }

      it "returns 404 when trying to delete another organization's document" do
        membership.update!(role: "admin")
        delete "/api/v1/documents/#{other_document.id}", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    describe "successful deletion" do
      before { membership.update!(role: "admin") }

      it "deletes the document" do
        expect {
          delete "/api/v1/documents/#{document.id}", headers: headers
        }.to change(Document, :count).by(-1)
      end

      it "returns 204 No Content" do
        delete "/api/v1/documents/#{document.id}", headers: headers
        expect(response).to have_http_status(:no_content)
      end
    end
  end

  # ── POST /api/v1/documents/:id/reprocess ────────────────────────────

  describe "POST /api/v1/documents/:id/reprocess" do
    let!(:document) { create_document(attrs: { status: "failed", error_message: "Something went wrong" }) }

    describe "authentication" do
      it "rejects unauthenticated requests" do
        post "/api/v1/documents/#{document.id}/reprocess"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe "authorization" do
      it "rejects viewers from reprocessing" do
        membership.update!(role: "viewer")
        post "/api/v1/documents/#{document.id}/reprocess", headers: headers
        expect(response).to have_http_status(:forbidden)
      end

      it "rejects members from reprocessing" do
        post "/api/v1/documents/#{document.id}/reprocess", headers: headers
        expect(response).to have_http_status(:forbidden)
      end

      it "allows admins to reprocess" do
        membership.update!(role: "admin")
        post "/api/v1/documents/#{document.id}/reprocess", headers: headers
        expect(response).to have_http_status(:ok)
      end
    end

    describe "tenant isolation" do
      let(:other_document) { create_document(org: other_org, attrs: { title: "Secret", status: "failed" }) }

      it "returns 404 when trying to reprocess another organization's document" do
        membership.update!(role: "admin")
        post "/api/v1/documents/#{other_document.id}/reprocess", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    describe "successful reprocess" do
      before do
        membership.update!(role: "admin")
        ActiveJob::Base.queue_adapter = :test
      end

      it "resets the document status to pending" do
        post "/api/v1/documents/#{document.id}/reprocess", headers: headers
        expect(response).to have_http_status(:ok)
        data = response.parsed_body["data"]
        expect(data["status"]).to eq("pending")
      end

      it "clears the error_message" do
        post "/api/v1/documents/#{document.id}/reprocess", headers: headers
        data = response.parsed_body["data"]
        expect(data["error_message"]).to be_nil
      end

      it "rejects reprocessing while document is currently processing" do
        document.update!(status: "processing")
        post "/api/v1/documents/#{document.id}/reprocess", headers: headers
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["detail"]).to include("currently being processed")
      end

      it "enqueues a ProcessDocumentJob" do
        expect {
          post "/api/v1/documents/#{document.id}/reprocess", headers: headers
        }.to have_enqueued_job(ProcessDocumentJob)
      end
    end
  end
end
