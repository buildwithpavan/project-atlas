# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::TextExtractor do
  let(:organization) { Organization.create!(name: "Acme", slug: "acme") }

  def create_document(content:, content_type:, filename:)
    doc = Document.create!(
      organization: organization,
      title: filename,
      filename: filename,
      content_type: content_type,
      file_size: content.bytesize
    )
    doc.file.attach(
      io: StringIO.new(content),
      filename: filename,
      content_type: content_type
    )
    doc
  end

  describe "TXT extraction" do
    it "extracts plain text content" do
      doc = create_document(content: "Hello world", content_type: "text/plain", filename: "notes.txt")
      result = described_class.call(doc)
      expect(result).to eq("Hello world")
    end

    it "handles UTF-8 content" do
      doc = create_document(content: "Héllo wörld — emojis: 🎉", content_type: "text/plain", filename: "unicode.txt")
      result = described_class.call(doc)
      expect(result).to include("Héllo wörld")
    end

    it "handles empty text files" do
      doc = create_document(content: "", content_type: "text/plain", filename: "empty.txt")
      result = described_class.call(doc)
      expect(result).to eq("")
    end
  end

  describe "Markdown extraction" do
    it "extracts markdown content as-is" do
      content = "# Title\n\nSome **bold** text."
      doc = create_document(content: content, content_type: "text/markdown", filename: "readme.md")
      result = described_class.call(doc)
      expect(result).to eq(content)
    end

    it "handles text/x-markdown content type" do
      content = "# Guide\n\nInstructions here."
      doc = create_document(content: content, content_type: "text/x-markdown", filename: "guide.md")
      result = described_class.call(doc)
      expect(result).to eq(content)
    end
  end

  describe "CSV extraction" do
    it "converts CSV rows into labeled text" do
      csv_content = "name,email\nAlice,alice@example.com\nBob,bob@example.com\n"
      doc = create_document(content: csv_content, content_type: "text/csv", filename: "contacts.csv")
      result = described_class.call(doc)
      expect(result).to include("name: Alice")
      expect(result).to include("email: alice@example.com")
      expect(result).to include("name: Bob")
    end

    it "handles CSV with various delimiters gracefully" do
      csv_content = "col1,col2\nval1,val2\n"
      doc = create_document(content: csv_content, content_type: "text/csv", filename: "data.csv")
      result = described_class.call(doc)
      expect(result).to include("col1: val1")
    end
  end

  describe "PDF extraction" do
    it "extracts text from a valid PDF" do
      pdf_content = create_minimal_pdf("Hello from PDF")
      doc = create_document(content: pdf_content, content_type: "application/pdf", filename: "test.pdf")
      result = described_class.call(doc)
      expect(result).to include("Hello from PDF")
    end
  end

  describe "unsupported formats" do
    it "raises ValidationError for unsupported content type" do
      doc = create_document(content: "binary", content_type: "application/octet-stream", filename: "app.exe")
      expect {
        described_class.call(doc)
      }.to raise_error(ValidationError, /Unsupported content type/)
    end

    it "raises ValidationError for image content type" do
      doc = create_document(content: "fake png", content_type: "image/png", filename: "photo.png")
      expect {
        described_class.call(doc)
      }.to raise_error(ValidationError, /Unsupported content type/)
    end
  end

  describe "missing file" do
    it "raises ValidationError when no file is attached" do
      doc = Document.create!(
        organization: organization,
        title: "No File",
        filename: "missing.txt",
        content_type: "text/plain",
        file_size: 0
      )
      expect {
        described_class.call(doc)
      }.to raise_error(ValidationError, /No file attached/)
    end
  end

  private

  def create_minimal_pdf(text)
    # Build a minimal valid PDF with correct xref offsets
    content = text.encode("ASCII", undef: :replace, replace: "?")
    stream = "BT /F1 12 Tf 100 700 Td (#{content}) Tj ET"

    objects = []
    offsets = []

    header = "%PDF-1.4\n"
    pos = header.length

    # Object 1: Catalog
    offsets << pos
    obj1 = "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n"
    objects << obj1
    pos += obj1.length

    # Object 2: Pages
    offsets << pos
    obj2 = "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n"
    objects << obj2
    pos += obj2.length

    # Object 3: Page
    offsets << pos
    obj3 = "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>\nendobj\n"
    objects << obj3
    pos += obj3.length

    # Object 4: Content stream
    offsets << pos
    obj4 = "4 0 obj\n<< /Length #{stream.length} >>\nstream\n#{stream}\nendstream\nendobj\n"
    objects << obj4
    pos += obj4.length

    # Object 5: Font
    offsets << pos
    obj5 = "5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n"
    objects << obj5
    pos += obj5.length

    xref_offset = pos

    xref = +"xref\n0 6\n"
    xref << "0000000000 65535 f \n"
    offsets.each do |o|
      xref << format("%010d 00000 n \n", o)
    end

    trailer = "trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n#{xref_offset}\n%%EOF\n"

    header + objects.join + xref + trailer
  end
end
