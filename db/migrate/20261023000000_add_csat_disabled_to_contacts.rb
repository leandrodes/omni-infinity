# frozen_string_literal: true

class AddCsatDisabledToContacts < ActiveRecord::Migration[7.2]
  def change
    add_column :contacts, :csat_disabled, :boolean, default: false, null: false
  end
end
