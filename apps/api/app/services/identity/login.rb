# frozen_string_literal: true

module Identity
  class Login < ApplicationService
    def initialize(params)
      @email = params[:email]
      @password = params[:password]
    end

    def call
      user = find_user
      authenticate!(user)

      token = Identity::AccessToken.encode(user)

      { access_token: token, expires_in: Identity::AccessToken::EXPIRATION }
    end

    private

    attr_reader :email, :password

    def find_user
      return nil if email.blank?

      User.where("lower(email) = ?", email.downcase).first
    end

    def authenticate!(user)
      raise UnauthorizedError, "Invalid email or password" unless user&.authenticate(password.to_s)
    end
  end
end
