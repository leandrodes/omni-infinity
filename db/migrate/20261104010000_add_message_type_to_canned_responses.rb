class AddMessageTypeToCannedResponses < ActiveRecord::Migration[7.2]
  def change
    add_column :canned_responses, :message_type, :string, null: false, default: 'quick'
    add_index :canned_responses, [:account_id, :message_type]
  end
end
