# frozen_string_literal: true

module Api
  module V1
    module Auth
      class RegistrationsController < BaseController
        def create
          result = Identity::RegisterUser.call(registration_params)

          render json: {
            data: {
              user: serialize_user(result[:user]),
              organization: serialize_organization(result[:organization])
            }
          }, status: :created
        end

        private

        def registration_params
          params.permit(:first_name, :last_name, :email, :password, :password_confirmation, :organization_name)
        end

        def serialize_user(user)
          {
            id: user.id,
            email: user.email,
            first_name: user.first_name,
            last_name: user.last_name
          }
        end

        def serialize_organization(organization)
          {
            id: organization.id,
            name: organization.name,
            slug: organization.slug
          }
        end
      end
    end
  end
end
