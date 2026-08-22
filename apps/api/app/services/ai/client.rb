# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module Ai
  # HTTP client for communicating with the Atlas FastAPI AI service.
  #
  # Configuration:
  #   ENV["AI_SERVICE_URL"]     - base URL (default: http://ai:8000)
  #   ENV["AI_SERVICE_TIMEOUT"] - request timeout in seconds (default: 10)
  #
  # Does not implement retries. Sidekiq handles retry logic at the job level.
  # Does not log request/response bodies to protect sensitive ticket content.
  class Client
    class Error < StandardError; end
    class ConnectionError < Error; end
    class TimeoutError < Error; end

    class HttpError < Error
      attr_reader :status

      def initialize(message, status:)
        @status = status
        super(message)
      end
    end

    class InvalidResponseError < Error; end

    def initialize(base_url: nil, timeout: nil)
      @base_url = base_url || ENV.fetch("AI_SERVICE_URL", "http://ai:8000")
      @timeout = timeout || ENV.fetch("AI_SERVICE_TIMEOUT", "10").to_i
    end

    def post(path, body)
      uri = URI.join(@base_url, path)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(body)

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      response = execute(uri, request)
      duration = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time).round(3)

      Rails.logger.info("AI service request method=POST path=#{path} status=#{response.code} duration=#{duration}s")

      handle_response(response, path)
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH, SocketError => e
      raise ConnectionError, "AI service unavailable: #{e.message}"
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      raise TimeoutError, "AI service timeout: #{e.message}"
    end

    private

    def execute(uri, request)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                          open_timeout: @timeout,
                                          read_timeout: @timeout) do |http|
        http.request(request)
      end
    end

    def handle_response(response, path)
      status = response.code.to_i

      unless (200..299).cover?(status)
        raise HttpError.new("AI service returned HTTP #{status} for #{path}", status: status)
      end

      parse_json(response.body)
    end

    def parse_json(body)
      JSON.parse(body)
    rescue JSON::ParserError => e
      raise InvalidResponseError, "AI service returned invalid JSON: #{e.message}"
    end
  end
end
