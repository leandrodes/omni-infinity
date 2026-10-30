class AddVisibilityToConversations < ActiveRecord::Migration[7.2]
  def change
    add_column :conversations, :visibility, :integer, default: 0, null: false
    add_column :conversations, :private_owner_id, :bigint
    add_index :conversations, [:account_id, :visibility]
    add_index :conversations, :private_owner_id
    add_foreign_key :conversations, :users, column: :private_owner_id, on_delete: :nullify
  end
end
