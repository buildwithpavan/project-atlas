# frozen_string_literal: true

# CORS configuration for the Voceive API.
#
# In production, set CORS_ALLOWED_ORIGINS to a comma-separated list of
# allowed frontend origins:
#
#   CORS_ALLOWED_ORIGINS=https://voceive.example.com,https://staging.voceive.example.com
#
# In development, defaults to common local dev server origins.
# When the frontend is served by nginx on the same origin (proxy mode),
# CORS headers are not needed, but configuring them is harmless.

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins_list = if Rails.env.production?
      ENV.fetch("CORS_ALLOWED_ORIGINS", "").split(",").map(&:strip).reject(&:empty?)
    else
      ENV.fetch("CORS_ALLOWED_ORIGINS", "http://localhost:5173,http://localhost:4173,http://127.0.0.1:5173").split(",").map(&:strip)
    end

    origins(*origins_list) if origins_list.any?

    resource "/api/*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      credentials: false,
      max_age: 3600
  end
end
