# frozen_string_literal: true

class AddErrorMessageToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :error_message, :text
  end
end
