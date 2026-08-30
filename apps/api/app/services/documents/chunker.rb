# frozen_string_literal: true

module Documents
  # Recursive text splitter with semantic boundaries.
  #
  # Target: ~500 tokens per chunk (~2000 characters)
  # Overlap: ~50 tokens (~200 characters)
  #
  # Token estimation: characters / 4
  #
  # Split priority:
  #   1. paragraph boundary "\n\n"
  #   2. line boundary "\n"
  #   3. sentence boundary (". ", "? ", "! ")
  #   4. word boundary " "
  class Chunker < ApplicationService
    TARGET_CHARS = 2000  # ~500 tokens
    OVERLAP_CHARS = 200  # ~50 tokens

    SEPARATORS = ["\n\n", "\n", ". ", "? ", "! ", " "].freeze

    # Matches Markdown-style headings and reasonable plain-text heading patterns
    HEADING_PATTERN = /\A(?:\#{1,6}\s+.+|[A-Z][A-Za-z0-9 :—–-]{2,80})\s*\z/

    Chunk = Struct.new(:content, :position, :token_count, :metadata, keyword_init: true)

    def initialize(text, metadata: {})
      @text = text.to_s
      @base_metadata = metadata
    end

    def call
      return [] if @text.strip.empty?

      raw_segments = recursive_split(@text, SEPARATORS)
      merged = merge_segments(raw_segments)
      with_overlap = apply_overlap(merged)

      current_heading = nil
      with_overlap.each_with_index.map do |content, index|
        # Track headings for section_title metadata
        content.each_line do |line|
          stripped = line.strip
          current_heading = stripped if stripped.match?(HEADING_PATTERN) && stripped.length > 1
        end

        token_count = (content.length / 4.0).ceil
        chunk_metadata = @base_metadata.merge(section_title: current_heading).compact

        Chunk.new(
          content: content,
          position: index,
          token_count: token_count,
          metadata: chunk_metadata
        )
      end
    end

    private

    def recursive_split(text, separators)
      return [text] if text.length <= TARGET_CHARS

      # If no separators left, hard-split by character limit
      if separators.empty?
        return text.scan(/.{1,#{TARGET_CHARS}}/m)
      end

      separator = separators.first
      parts = text.split(separator, -1)

      # If splitting didn't help, try the next separator
      if parts.length <= 1
        return recursive_split(text, separators[1..])
      end

      segments = []
      parts.each_with_index do |part, i|
        # Re-append the separator to preserve content (except for the last part)
        segment = i < parts.length - 1 ? "#{part}#{separator}" : part
        next if segment.strip.empty?

        if segment.length <= TARGET_CHARS
          segments << segment
        else
          segments.concat(recursive_split(segment, separators[1..]))
        end
      end

      segments
    end

    def merge_segments(segments)
      return segments if segments.empty?

      merged = []
      current = +""

      segments.each do |segment|
        if current.empty?
          current = +segment
        elsif (current.length + segment.length) <= TARGET_CHARS
          current << segment
        else
          merged << current unless current.strip.empty?
          current = +segment
        end
      end

      merged << current unless current.strip.empty?
      merged
    end

    def apply_overlap(chunks)
      return chunks if chunks.length <= 1

      result = [chunks.first]

      (1...chunks.length).each do |i|
        prev_chunk = chunks[i - 1]
        overlap_text = extract_overlap(prev_chunk)
        current = "#{overlap_text}#{chunks[i]}"
        result << current
      end

      result
    end

    def extract_overlap(text)
      return "" if text.length <= OVERLAP_CHARS

      # Take the last OVERLAP_CHARS characters and break on word boundary
      tail = text[-(OVERLAP_CHARS)..]
      word_boundary = tail.index(" ")
      word_boundary ? tail[(word_boundary + 1)..] : tail
    end
  end
end
