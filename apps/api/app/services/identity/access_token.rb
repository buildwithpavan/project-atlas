# frozen_string_literal: true

module Identity
  class AccessToken
    ALGORITHM = "HS256"
    EXPIRATION = 3600 # 1 hour, per docs/12-identity-api.md

    class << self
      def encode(user)
        payload = {
          sub: user.id,
          iat: Time.current.to_i,
          exp: EXPIRATION.seconds.from_now.to_i
        }

        JWT.encode(payload, secret_key, ALGORITHM)
      end

      def decode(token)
        payload = JWT.decode(token, secret_key, true, {
          algorithm: ALGORITHM,
          required_claims: %w[sub iat exp]
        }).first

        payload.symbolize_keys
      rescue JWT::ExpiredSignature
        raise UnauthorizedError, "Token has expired"
      rescue JWT::DecodeError
        raise UnauthorizedError, "Invalid token"
      end

      private

      def secret_key
        Rails.application.secret_key_base
      end
    end
  end
end
