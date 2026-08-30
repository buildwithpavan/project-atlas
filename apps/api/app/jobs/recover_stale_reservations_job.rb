# frozen_string_literal: true

# Recovers stale AI quota reservations from crashed processes.
#
# When an AI request reserves tokens but the process crashes before
# releasing, the reservation becomes "stale." This job resets
# reservations older than the configured expiry threshold.
#
# Safe under concurrent execution. Idempotent.
#
# Configuration:
#   AI_RESERVATION_EXPIRY_SECONDS — how old a reservation must be before
#     recovery (default: 300 = 5 minutes)
class RecoverStaleReservationsJob < ApplicationJob
  queue_as :default

  def perform
    recovered = ::Ai::QuotaEnforcer.recover_stale_reservations!

    Rails.logger.info(
      "[ReservationRecovery] completed recovered=#{recovered}"
    )
  end
end
