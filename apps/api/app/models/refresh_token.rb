# frozen_string_literal: true

class RefreshToken < ApplicationRecord
  EXPIRATION = 30.days
  TOKEN_LENGTH = 32 # bytes, 256 bits of entropy

  belongs_to :user

  validates :token_digest, presence: true, uniqueness: true
  validates :family_id, presence: true
  validates :expires_at, presence: true

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  def expired?
    expires_at <= Time.current
  end

  def revoked?
    revoked_at.present?
  end

  def revoke!
    update!(revoked_at: Time.current) unless revoked?
  end

  class << self
    def generate_token
      SecureRandom.urlsafe_base64(TOKEN_LENGTH)
    end

    def digest(raw_token)
      OpenSSL::Digest::SHA256.hexdigest(raw_token)
    end

    def revoke_family!(family_id)
      where(family_id: family_id, revoked_at: nil)
        .update_all(revoked_at: Time.current)
    end
  end
end
