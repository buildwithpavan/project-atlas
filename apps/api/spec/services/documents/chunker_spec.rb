# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documents::Chunker, type: :service do
  def chunk(text, metadata: {})
    described_class.call(text, metadata: metadata)
  end

  describe "empty input" do
    it "returns empty array for nil" do
      expect(chunk(nil)).to eq([])
    end

    it "returns empty array for empty string" do
      expect(chunk("")).to eq([])
    end

    it "returns empty array for whitespace-only" do
      expect(chunk("   \n\n   ")).to eq([])
    end
  end

  describe "small text" do
    it "returns a single chunk for short text" do
      result = chunk("Hello world.")
      expect(result.length).to eq(1)
      expect(result[0].content).to include("Hello world.")
      expect(result[0].position).to eq(0)
    end

    it "estimates token count as characters / 4" do
      text = "a" * 100
      result = chunk(text)
      expect(result[0].token_count).to eq(25)
    end
  end

  describe "paragraph splitting" do
    it "splits on double newlines" do
      text = (["Paragraph content. " * 60] * 3).join("\n\n")
      result = chunk(text)
      expect(result.length).to be >= 3
    end

    it "preserves paragraph content" do
      para1 = "First paragraph. " * 60
      para2 = "Second paragraph. " * 60
      text = "#{para1}\n\n#{para2}"
      result = chunk(text)
      all_content = result.map(&:content).join
      expect(all_content).to include("First paragraph")
      expect(all_content).to include("Second paragraph")
    end
  end

  describe "recursive splitting" do
    it "falls back to line splitting for long paragraphs" do
      lines = 50.times.map { |i| "Line #{i} with enough content to matter for splitting." }
      text = lines.join("\n")
      result = chunk(text)
      expect(result.length).to be >= 2
    end

    it "falls back to sentence splitting for very long lines" do
      sentences = 100.times.map { |i| "This is sentence number #{i} with additional context" }
      text = sentences.join(". ")
      result = chunk(text)
      expect(result.length).to be >= 2
    end

    it "falls back to word splitting for extremely long strings" do
      text = "word " * 2000
      result = chunk(text)
      expect(result.length).to be >= 2
    end
  end

  describe "target chunk size" do
    it "produces chunks approximately ~2000 characters" do
      text = "Content sentence with reasonable length. " * 200
      result = chunk(text)
      result.each do |c|
        # Allow some flexibility: overlap and merging can push slightly over
        expect(c.content.length).to be <= 3000
      end
    end
  end

  describe "overlap" do
    it "includes overlap between consecutive chunks" do
      text = ("Paragraph with distinctive words like xylophone. " * 50 + "\n\n") * 5
      result = chunk(text)
      next if result.length < 2

      # The beginning of chunk 2 should share some text with the end of chunk 1
      tail_of_first = result[0].content[-100..]
      head_of_second = result[1].content[0..200]

      # Find any overlapping words
      tail_words = tail_of_first.split.last(5)
      shared = tail_words.select { |w| head_of_second.include?(w) }
      expect(shared).not_to be_empty
    end
  end

  describe "ordering" do
    it "assigns sequential positions starting from 0" do
      text = ("Paragraph. " * 200 + "\n\n") * 5
      result = chunk(text)
      expect(result.map(&:position)).to eq((0...result.length).to_a)
    end

    it "preserves text order" do
      text = "FIRST_MARKER " + ("filler " * 500) + " SECOND_MARKER"
      result = chunk(text)
      first_idx = result.index { |c| c.content.include?("FIRST_MARKER") }
      second_idx = result.index { |c| c.content.include?("SECOND_MARKER") }
      expect(first_idx).to be < second_idx
    end
  end

  describe "no empty chunks" do
    it "never produces chunks with empty content" do
      text = "\n\n\n\nSome content\n\n\n\nMore content\n\n\n\n"
      result = chunk(text)
      result.each do |c|
        expect(c.content.strip).not_to be_empty
      end
    end
  end

  describe "headings" do
    it "detects Markdown headings and sets section_title" do
      text = "# Introduction\n\n" + ("This is the introduction section with enough content to fill a chunk. " * 50) +
             "\n\n## Methods\n\n" + ("This is the methods section with enough content to fill another chunk. " * 50)
      result = chunk(text)
      titles = result.map { |c| c.metadata[:section_title] }.compact
      expect(titles).to include("# Introduction")
    end

    it "includes heading text in chunk content" do
      text = "# Overview\n\nDetailed content follows."
      result = chunk(text)
      expect(result.first.content).to include("# Overview")
    end
  end

  describe "metadata" do
    it "passes through base metadata" do
      result = chunk("Some text", metadata: { source_page: 1 })
      expect(result.first.metadata[:source_page]).to eq(1)
    end

    it "includes section_title when headings are found" do
      result = chunk("# Title\n\nContent here")
      expect(result.first.metadata).to have_key(:section_title)
    end
  end

  describe "special content" do
    it "handles lists" do
      text = (1..50).map { |i| "- Item #{i} with some description text" }.join("\n")
      result = chunk(text)
      expect(result).not_to be_empty
      all_content = result.map(&:content).join
      expect(all_content).to include("Item 1")
    end

    it "handles code blocks" do
      text = "Some intro text.\n\n```ruby\ndef hello\n  puts 'world'\nend\n```\n\nMore text after code."
      result = chunk(text)
      expect(result).not_to be_empty
      all_content = result.map(&:content).join
      expect(all_content).to include("def hello")
    end

    it "handles tables" do
      rows = (1..30).map { |i| "| Cell #{i} | Data #{i} | Value #{i} |" }
      text = "| Header 1 | Header 2 | Header 3 |\n" + rows.join("\n")
      result = chunk(text)
      expect(result).not_to be_empty
    end

    it "handles Unicode content" do
      text = "日本語テキスト。" * 300
      result = chunk(text)
      expect(result).not_to be_empty
      expect(result.first.content).to include("日本語")
    end

    it "handles very long individual lines" do
      text = "x" * 10_000
      result = chunk(text)
      expect(result.length).to be >= 2
    end
  end

  describe "chunk structure" do
    it "returns Chunk structs with required fields" do
      result = chunk("Test content")
      c = result.first
      expect(c).to respond_to(:content, :position, :token_count, :metadata)
      expect(c.content).to be_a(String)
      expect(c.position).to be_a(Integer)
      expect(c.token_count).to be_a(Integer)
      expect(c.metadata).to be_a(Hash)
    end
  end
end
