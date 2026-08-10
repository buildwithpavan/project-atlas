# frozen_string_literal: true

module Api
  module V1
    module Auth
      class RefreshController < BaseController
        def create
          result = Identity::RefreshSession.call(refresh_token: params[:refresh_token])

          render json: { data: result }
        end
      end
    end
  end
end
