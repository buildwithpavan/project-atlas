# frozen_string_literal: true

module Identity
  class RefreshSession < ApplicationService
    def initialize(refresh_token:)
      @raw_token = refresh_token
    end

    def call
      existing = find_token!

      # Reuse detection — outside transaction so family revocation persists
      if existing.revoked?
        RefreshToken.revoke_family!(existing.family_id)
        raise UnauthorizedError, "Invalid refresh token"
      end

      raise UnauthorizedError, "Invalid refresh token" if existing.expired?

      # Atomic rotation with pessimistic locking
      result = ActiveRecord::Base.transaction do
        existing.lock!
        existing.reload

        # Re-check after lock: concurrent rotation = reuse
        if existing.revoked? || existing.expired?
          raise ActiveRecord::Rollback
        end

        new_tokens = rotate!(existing)

        {
          access_token: Identity::AccessToken.encode(existing.user),
          refresh_token: new_tokens[:raw_token],
          expires_in: Identity::AccessToken::EXPIRATION
        }
      end

      # Transaction rolled back = concurrent rotation detected
      unless result
        RefreshToken.revoke_family!(existing.family_id)
        raise UnauthorizedError, "Invalid refresh token"
      end

      result
    end

    private

    attr_reader :raw_token

    def find_token!
      digest = RefreshToken.digest(raw_token.to_s)
      token = RefreshToken.find_by(token_digest: digest)

      raise UnauthorizedError, "Invalid refresh token" unless token

      token
    end

    def rotate!(existing)
      result = Identity::IssueRefreshToken.call(
        user: existing.user,
        family_id: existing.family_id
      )

      existing.update!(
        revoked_at: Time.current,
        replaced_by_token_id: result[:record].id
      )

      result
    end
  end
end
