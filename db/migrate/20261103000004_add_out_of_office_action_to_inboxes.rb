class AddOutOfOfficeActionToInboxes < ActiveRecord::Migration[7.2]
  def change
    change_table :inboxes, bulk: true do |t|
      t.string :out_of_office_action, null: false, default: 'none'
      t.bigint :out_of_office_team_id
    end

    add_index :inboxes, :out_of_office_team_id
    add_foreign_key :inboxes, :teams, column: :out_of_office_team_id, on_delete: :nullify
  end
end
