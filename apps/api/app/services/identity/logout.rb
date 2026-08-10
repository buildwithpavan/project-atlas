# frozen_string_literal: true

module Identity
  class Logout < ApplicationService
    def initialize(refresh_token:)
      @raw_token = refresh_token
    end

    def call
      token = find_token!

      RefreshToken.revoke_family!(token.family_id)
    end

    private

    attr_reader :raw_token

    def find_token!
      digest = RefreshToken.digest(raw_token.to_s)
      token = RefreshToken.find_by(token_digest: digest)

      raise UnauthorizedError, "Invalid refresh token" unless token

      token
    end
  end
end
