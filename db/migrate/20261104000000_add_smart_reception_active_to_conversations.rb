class AddSmartReceptionActiveToConversations < ActiveRecord::Migration[7.2]
  def change
    add_column :conversations, :smart_reception_active, :boolean, null: false, default: false
    add_index :conversations, [:account_id, :smart_reception_active],
              where: 'smart_reception_active = true',
              name: 'index_conversations_on_active_smart_reception'
  end
end
