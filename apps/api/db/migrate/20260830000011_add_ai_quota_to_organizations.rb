# frozen_string_literal: true

class AddAiQuotaToOrganizations < ActiveRecord::Migration[8.1]
  def change
    change_table :organizations do |t|
      # Monthly token limit (nil = unlimited). Enforced server-side.
      t.bigint :ai_monthly_token_limit, null: true

      # Monthly estimated cost limit in USD (nil = unlimited).
      t.decimal :ai_monthly_cost_limit, precision: 10, scale: 2, null: true
    end
  end
end
