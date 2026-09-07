# frozen_string_literal: true

module Identity
  class RegisterUser < ApplicationService
    def initialize(params)
      @params = params
    end

    def call
      ActiveRecord::Base.transaction do
        user = create_user!
        organization = create_organization!
        create_membership!(user: user, organization: organization)

        { user: user, organization: organization }
      end
    end

    private

    attr_reader :params

    def create_user!
      user = User.new(
        email: params[:email],
        first_name: params[:first_name],
        last_name: params[:last_name],
        password: params[:password],
        password_confirmation: params[:password_confirmation]
      )

      raise ValidationError.new("User validation failed", errors: user.errors.to_hash) unless user.save

      user
    rescue ActiveRecord::RecordNotUnique
      raise ValidationError.new("User validation failed", errors: { email: [ "has already been taken" ] })
    end

    def create_organization!
      organization = Organization.new(
        name: params[:organization_name],
        slug: generate_slug(params[:organization_name])
      )

      raise ValidationError.new("Organization validation failed", errors: organization.errors.to_hash) unless organization.save

      organization
    rescue ActiveRecord::RecordNotUnique
      raise ValidationError.new("Organization validation failed", errors: { slug: [ "has already been taken" ] })
    end

    def create_membership!(user:, organization:)
      membership = Membership.new(
        user: user,
        organization: organization,
        role: "owner"
      )

      raise ValidationError.new("Membership validation failed", errors: membership.errors.to_hash) unless membership.save

      membership
    end

    def generate_slug(name)
      return "" if name.blank?

      name.parameterize
    end
  end
end
