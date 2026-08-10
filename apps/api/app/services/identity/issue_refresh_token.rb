# frozen_string_literal: true

module Identity
  class IssueRefreshToken < ApplicationService
    def initialize(user:, family_id: nil)
      @user = user
      @family_id = family_id || SecureRandom.uuid
    end

    def call
      raw_token = RefreshToken.generate_token

      record = RefreshToken.create!(
        user: user,
        token_digest: RefreshToken.digest(raw_token),
        family_id: family_id,
        expires_at: RefreshToken::EXPIRATION.from_now
      )

      { raw_token: raw_token, record: record }
    end

    private

    attr_reader :user, :family_id
  end
end
