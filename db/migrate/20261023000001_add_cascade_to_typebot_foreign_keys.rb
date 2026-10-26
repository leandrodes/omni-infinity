# frozen_string_literal: true

class AddCascadeToTypebotForeignKeys < ActiveRecord::Migration[7.2]
  def up
    replace_foreign_key :typebot_conversations, :conversations
    replace_foreign_key :typebot_inbox_configs, :accounts
    replace_foreign_key :typebot_inbox_configs, :inboxes
    replace_foreign_key :typebot_account_workspaces, :accounts
  end

  def down
    replace_foreign_key :typebot_conversations, :conversations, on_delete: nil
    replace_foreign_key :typebot_inbox_configs, :accounts, on_delete: nil
    replace_foreign_key :typebot_inbox_configs, :inboxes, on_delete: nil
    replace_foreign_key :typebot_account_workspaces, :accounts, on_delete: nil
  end

  private

  def replace_foreign_key(from_table, to_table, on_delete: :cascade)
    remove_foreign_key from_table, to_table
    add_foreign_key from_table, to_table, on_delete: on_delete
  end
end
