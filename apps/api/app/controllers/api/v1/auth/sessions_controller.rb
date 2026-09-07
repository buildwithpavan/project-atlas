# frozen_string_literal: true

module Api
  module V1
    module Auth
      class SessionsController < BaseController
        def create
          result = Identity::Login.call(login_params)

          render json: { data: result }
        end

        private

        def login_params
          params.permit(:email, :password)
        end
      end
    end
  end
end
