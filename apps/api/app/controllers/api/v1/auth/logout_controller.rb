# frozen_string_literal: true

module Api
  module V1
    module Auth
      class LogoutController < BaseController
        def create
          Identity::Logout.call(refresh_token: params[:refresh_token])

          head :no_content
        end
      end
    end
  end
end
