class AddAvailabilityToCannedResponses < ActiveRecord::Migration[7.2]
  def change
    add_column :canned_responses, :available_for_all_inboxes, :boolean, null: false, default: true

    create_table :canned_response_inboxes do |t|
      t.references :canned_response, null: false, foreign_key: true
      t.references :inbox, null: false, foreign_key: true
      t.timestamps
    end

    add_index :canned_response_inboxes, [:canned_response_id, :inbox_id], unique: true,
                                                                          name: 'idx_canned_response_inboxes_unique'
  end
end
