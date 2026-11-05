class SwitchCannedResponseAvailabilityToTeams < ActiveRecord::Migration[7.2]
  def up
    add_column :canned_responses, :available_for_all_teams, :boolean, null: false, default: true

    create_table :canned_response_teams do |t|
      t.references :canned_response, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.timestamps
    end
    add_index :canned_response_teams, [:canned_response_id, :team_id], unique: true, name: 'idx_canned_response_teams_unique'

    remove_column :canned_responses, :available_for_all_inboxes, :boolean
    drop_table :canned_response_inboxes
  end

  def down
    create_table :canned_response_inboxes do |t|
      t.references :canned_response, null: false, foreign_key: true
      t.references :inbox, null: false, foreign_key: true
      t.timestamps
    end
    add_index :canned_response_inboxes, [:canned_response_id, :inbox_id], unique: true, name: 'idx_canned_response_inboxes_unique'

    add_column :canned_responses, :available_for_all_inboxes, :boolean, null: false, default: true
    drop_table :canned_response_teams
    remove_column :canned_responses, :available_for_all_teams, :boolean
  end
end
