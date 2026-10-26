# frozen_string_literal: true

class CreateTypebotIntegrationTables < ActiveRecord::Migration[7.2]
  def change
    create_table :typebot_account_workspaces do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.string :workspace_id, null: false
      t.string :workspace_name
      t.timestamps
    end

    add_index :typebot_account_workspaces, :workspace_id, unique: true

    create_table :typebot_inbox_configs do |t|
      t.references :account, null: false, foreign_key: true
      t.references :inbox, null: false, foreign_key: true, index: { unique: true }
      t.string :workspace_id, null: false
      t.string :typebot_id, null: false
      t.string :public_id
      t.boolean :active, null: false, default: true
      t.boolean :pause_on_assignee, null: false, default: true
      t.timestamps
    end

    add_index :typebot_inbox_configs, :typebot_id

    create_table :typebot_conversations do |t|
      t.references :conversation, null: false, foreign_key: true, index: { unique: true }
      t.string :session_id, null: false
      t.string :typebot_id
      t.datetime :last_activity_at
      t.timestamps
    end

    add_index :typebot_conversations, :session_id, unique: true
  end
end
