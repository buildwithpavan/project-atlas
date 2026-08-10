# frozen_string_literal: true

require "rails_helper"

RSpec.describe Identity::RegisterUser, type: :service do
  let(:valid_params) do
    {
      first_name: "Ada",
      last_name: "Lovelace",
      email: "ada@example.com",
      password: "secure_password",
      password_confirmation: "secure_password",
      organization_name: "Acme Inc"
    }
  end

  describe ".call" do
    context "with valid params" do
      it "creates a User" do
        expect { described_class.call(valid_params) }.to change(User, :count).by(1)
      end

      it "creates an Organization" do
        expect { described_class.call(valid_params) }.to change(Organization, :count).by(1)
      end

      it "creates a Membership" do
        expect { described_class.call(valid_params) }.to change(Membership, :count).by(1)
      end

      it "assigns the owner role to the membership" do
        result = described_class.call(valid_params)
        membership = Membership.find_by(user: result[:user], organization: result[:organization])
        expect(membership.role).to eq("owner")
      end

      it "associates the user with the organization through membership" do
        result = described_class.call(valid_params)
        expect(result[:user].organizations).to include(result[:organization])
      end

      it "stores password securely via password_digest" do
        result = described_class.call(valid_params)
        expect(result[:user].password_digest).to be_present
        expect(result[:user].password_digest).not_to eq("secure_password")
      end

      it "generates a slug from the organization name" do
        result = described_class.call(valid_params)
        expect(result[:organization].slug).to eq("acme-inc")
      end
    end

    context "with duplicate email" do
      before { described_class.call(valid_params) }

      it "raises a ValidationError" do
        new_params = valid_params.merge(organization_name: "Other Org")
        expect { described_class.call(new_params) }.to raise_error(ValidationError) do |error|
          expect(error.errors[:email]).to include("has already been taken")
        end
      end

      it "does not create additional records" do
        new_params = valid_params.merge(organization_name: "Other Org")
        expect {
          described_class.call(new_params) rescue nil
        }.not_to change(Organization, :count)
      end
    end

    context "with invalid user data" do
      it "raises ValidationError when email is blank" do
        params = valid_params.merge(email: "")
        expect { described_class.call(params) }.to raise_error(ValidationError)
      end

      it "raises ValidationError when email is invalid" do
        params = valid_params.merge(email: "not-an-email")
        expect { described_class.call(params) }.to raise_error(ValidationError)
      end

      it "raises ValidationError when first_name is blank" do
        params = valid_params.merge(first_name: "")
        expect { described_class.call(params) }.to raise_error(ValidationError)
      end
    end

    context "with invalid organization data" do
      it "raises ValidationError when organization_name is blank" do
        params = valid_params.merge(organization_name: "")
        expect { described_class.call(params) }.to raise_error(ValidationError)
      end

      it "does not persist the user when organization creation fails" do
        params = valid_params.merge(organization_name: "")
        expect {
          described_class.call(params) rescue nil
        }.not_to change(User, :count)
      end
    end

    context "with password confirmation mismatch" do
      it "raises ValidationError" do
        params = valid_params.merge(password_confirmation: "different")
        expect { described_class.call(params) }.to raise_error(ValidationError)
      end
    end

    context "transaction rollback" do
      it "rolls back user and organization when membership creation fails" do
        # Stub Membership to simulate save failure
        allow_any_instance_of(Membership).to receive(:save).and_return(false)
        allow_any_instance_of(Membership).to receive(:errors).and_return(
          ActiveModel::Errors.new(Membership.new).tap { |e| e.add(:base, "forced failure") }
        )

        expect {
          described_class.call(valid_params) rescue nil
        }.not_to change(User, :count)

        expect(Organization.count).to eq(0)
      end
    end
  end
end
