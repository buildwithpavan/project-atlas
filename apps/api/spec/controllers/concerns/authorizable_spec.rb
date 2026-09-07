# frozen_string_literal: true

require "rails_helper"

RSpec.describe Authorizable, type: :controller do
  controller(ApplicationController) do
    include Authenticatable
    include Authorizable
    before_action :authenticate_user!

    def read_action
      authorize! :read
      render json: { ok: true }
    end

    def write_action
      authorize! :write
      render json: { ok: true }
    end

    def manage_action
      authorize! :manage
      render json: { ok: true }
    end

    def own_action
      authorize! :own
      render json: { ok: true }
    end
  end

  before do
    routes.draw do
      get "read_action" => "anonymous#read_action"
      get "write_action" => "anonymous#write_action"
      get "manage_action" => "anonymous#manage_action"
      get "own_action" => "anonymous#own_action"
    end
  end

  let(:organization) { Organization.create!(name: "Test", slug: "test") }
  let(:user) { User.create!(email: "u@e.com", first_name: "A", last_name: "B", password: "password123") }

  before do
    request.headers["Authorization"] = "Bearer #{Identity::AccessToken.encode(user)}"
  end

  shared_examples "allows access" do |action|
    it "returns 200" do
      get action
      expect(response).to have_http_status(:ok)
    end
  end

  shared_examples "denies access" do |action|
    it "returns 403" do
      get action
      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body["type"]).to eq("/errors/forbidden")
    end
  end

  context "with owner role" do
    before { Membership.create!(user: user, organization: organization, role: "owner") }

    include_examples "allows access", :read_action
    include_examples "allows access", :write_action
    include_examples "allows access", :manage_action
    include_examples "allows access", :own_action
  end

  context "with admin role" do
    before { Membership.create!(user: user, organization: organization, role: "admin") }

    include_examples "allows access", :read_action
    include_examples "allows access", :write_action
    include_examples "allows access", :manage_action
    include_examples "denies access", :own_action
  end

  context "with member role" do
    before { Membership.create!(user: user, organization: organization, role: "member") }

    include_examples "allows access", :read_action
    include_examples "allows access", :write_action
    include_examples "denies access", :manage_action
    include_examples "denies access", :own_action
  end

  context "with viewer role" do
    before { Membership.create!(user: user, organization: organization, role: "viewer") }

    include_examples "allows access", :read_action
    include_examples "denies access", :write_action
    include_examples "denies access", :manage_action
    include_examples "denies access", :own_action
  end

  context "with no organization membership" do
    it "returns 401" do
      get :read_action
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
