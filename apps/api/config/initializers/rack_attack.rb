# frozen_string_literal: true

# Rate limiting configuration using Rack::Attack.
#
# All limits are env-configurable. Responses use RFC 9457 Problem Details.

class Rack::Attack
  ### Throttle Rules ###

  # Login: 5 attempts per minute per IP (brute-force protection)
  throttle("auth/login", limit: ENV.fetch("RATE_LIMIT_LOGIN", 5).to_i, period: 1.minute) do |req|
    req.ip if req.path == "/api/v1/auth/login" && req.post?
  end

  # Registration: 5 attempts per hour per IP
  throttle("auth/register", limit: ENV.fetch("RATE_LIMIT_REGISTER", 5).to_i, period: 1.hour) do |req|
    req.ip if req.path == "/api/v1/auth/register" && req.post?
  end

  # Token refresh: 20 per minute per IP
  throttle("auth/refresh", limit: ENV.fetch("RATE_LIMIT_REFRESH", 20).to_i, period: 1.minute) do |req|
    req.ip if req.path == "/api/v1/auth/refresh" && req.post?
  end

  # Authenticated API: 100 requests per minute per IP
  throttle("api/authenticated", limit: ENV.fetch("RATE_LIMIT_API", 100).to_i, period: 1.minute) do |req|
    if req.path.start_with?("/api/v1/") &&
       !req.path.start_with?("/api/v1/auth/") &&
       req.path != "/api/v1/health"
      req.ip
    end
  end

  # AI messages: stricter per-user limit for the expensive AI endpoint.
  # Keyed by authenticated user ID (from JWT) rather than IP to avoid
  # blocking legitimate users behind shared NAT/proxies.
  # Default: 20 AI requests per minute per user.
  throttle("ai/messages", limit: ENV.fetch("RATE_LIMIT_AI_MESSAGES", 20).to_i, period: 1.minute) do |req|
    if req.post? && req.path.match?(%r{\A/api/v1/conversations/[^/]+/messages\z})
      token = req.get_header("HTTP_AUTHORIZATION")&.delete_prefix("Bearer ")
      if token.present?
        begin
          payload = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: "HS256").first
          payload["sub"]
        rescue JWT::DecodeError
          nil
        end
      end
    end
  end

  ### Custom Throttled Response ###
  # Return RFC 9457 Problem Details JSON on 429
  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"] || {}
    period = match_data[:period] || 60
    retry_after = (period - (Time.now.to_i % period)).to_s

    body = {
      type: "/errors/rate-limited",
      title: "Too Many Requests",
      status: 429,
      detail: "Rate limit exceeded. Try again in #{retry_after} seconds."
    }.to_json

    [
      429,
      {
        "Content-Type" => "application/json; charset=utf-8",
        "Retry-After" => retry_after
      },
      [body]
    ]
  end
end
