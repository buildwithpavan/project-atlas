# frozen_string_literal: true

class MakeOrganizationNameAndSlugRequired < ActiveRecord::Migration[8.1]
  def change
    change_column_null :organizations, :name, false
    change_column_null :organizations, :slug, false
  end
end