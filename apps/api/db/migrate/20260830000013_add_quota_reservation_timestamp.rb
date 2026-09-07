# frozen_string_literal: true

# Phase 3L: Add timestamp for quota reservation recovery.
#
# Tracks when a reservation was last made so stale reservations
# (from crashed processes) can be safely recovered.
# Also adds ai_quota_reservation_expires_at for expiry-based recovery.
class AddQuotaReservationTimestamp < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :ai_quota_reserved_at, :datetime
  end
end
