class AddRefreshTokenConstraints < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :refresh_tokens, :refresh_tokens, column: :replaced_by_token_id, on_delete: :nullify
    add_index :refresh_tokens, :expires_at
  end
end
