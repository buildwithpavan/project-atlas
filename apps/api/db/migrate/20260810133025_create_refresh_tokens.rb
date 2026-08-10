class CreateRefreshTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :refresh_tokens, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.uuid :family_id, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.uuid :replaced_by_token_id

      t.timestamps
    end

    add_index :refresh_tokens, :token_digest, unique: true
    add_index :refresh_tokens, :family_id
  end
end
