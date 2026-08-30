# frozen_string_literal: true

# Concern providing organization scoping and role-based authorization.
#
# Requires Authenticatable to be included first (provides current_user).
#
# Permission matrix:
#   owner  → full access (manage org, write, read)
#   admin  → full write + read (no org management)
#   member → limited write (upload) + read
#   viewer → read-only
#
# Usage in controllers:
#   authorize! :read     # viewer and above
#   authorize! :write    # member and above (for uploads)
#   authorize! :manage   # admin and above
#   authorize! :own      # owner only
module Authorizable
  extend ActiveSupport::Concern

  PERMISSION_HIERARCHY = {
    "owner"  => %i[own manage write read],
    "admin"  => %i[manage write read],
    "member" => %i[write read],
    "viewer" => %i[read]
  }.freeze

  private

  def current_organization
    @current_organization ||= begin
      org = current_user.organizations.first
      raise UnauthorizedError, "No organization access" unless org
      org
    end
  end

  def current_membership
    @current_membership ||= current_user.memberships.find_by(organization: current_organization)
  end

  def authorize!(permission)
    role = current_membership&.role
    raise ForbiddenError unless role

    allowed = PERMISSION_HIERARCHY.fetch(role, [])
    raise ForbiddenError unless allowed.include?(permission)
  end
end
