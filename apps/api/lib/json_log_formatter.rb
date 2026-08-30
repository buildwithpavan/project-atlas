# frozen_string_literal: true

# JSON log formatter for production environments.
# Outputs structured logs compatible with CloudWatch, Datadog, ELK, etc.
class JsonLogFormatter < ::Logger::Formatter
  def call(severity, timestamp, _progname, message)
    entry = {
      level: severity,
      timestamp: timestamp.utc.iso8601(3),
      message: message.is_a?(String) ? message.strip : message.inspect
    }

    "#{entry.to_json}\n"
  end
end
