# frozen_string_literal: true

module Authenticatable
  extend ActiveSupport::Concern

  private

  def authenticate_user!
    token = extract_bearer_token
    raise UnauthorizedError, "Missing authorization header" unless token

    payload = Identity::AccessToken.decode(token)
    @current_user = User.find_by(id: payload[:sub])

    raise UnauthorizedError, "User not found" unless @current_user
  end

  def current_user
    @current_user
  end

  def extract_bearer_token
    header = request.headers["Authorization"]
    return nil unless header&.start_with?("Bearer ")

    header.delete_prefix("Bearer ")
  end
end
