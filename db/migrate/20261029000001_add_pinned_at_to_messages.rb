class AddPinnedAtToMessages < ActiveRecord::Migration[7.2]
  def change
    add_column :messages, :pinned_at, :datetime
    add_column :messages, :pinned_by_id, :bigint
    add_index :messages, [:conversation_id, :pinned_at]
    add_foreign_key :messages, :users, column: :pinned_by_id, on_delete: :nullify
  end
end
