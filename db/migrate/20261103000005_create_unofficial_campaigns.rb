# rubocop:disable Metrics/AbcSize, Metrics/MethodLength
class CreateUnofficialCampaigns < ActiveRecord::Migration[7.2]
  def change
    create_table :unofficial_campaigns do |t|
      t.references :account, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.integer :status, null: false, default: 0
      t.string :start_mode, null: false, default: 'immediate'
      t.datetime :scheduled_at
      t.datetime :started_at
      t.datetime :completed_at
      t.jsonb :sender_inbox_ids, null: false, default: []
      t.integer :min_contact_interval_seconds, null: false, default: 30
      t.integer :max_contact_interval_seconds, null: false, default: 90
      t.boolean :pause_enabled, null: false, default: false
      t.integer :pause_every_min_contacts, null: false, default: 10
      t.integer :pause_every_max_contacts, null: false, default: 20
      t.integer :pause_min_minutes, null: false, default: 10
      t.integer :pause_max_minutes, null: false, default: 20
      t.jsonb :allowed_days, null: false, default: [0, 1, 2, 3, 4, 5, 6]
      t.integer :allowed_start_minute, null: false, default: 480
      t.integer :allowed_end_minute, null: false, default: 1080
      t.string :post_action, null: false, default: 'pending_team'
      t.bigint :post_team_id
      t.bigint :post_agent_id
      t.integer :next_sender_index, null: false, default: 0
      t.integer :next_pause_count, null: false, default: 0
      t.timestamps
    end

    add_index :unofficial_campaigns, :status

    create_table :unofficial_campaign_messages do |t|
      t.references :unofficial_campaign, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.integer :wait_min_seconds, null: false, default: 3
      t.integer :wait_max_seconds, null: false, default: 8
      t.timestamps
    end

    create_table :unofficial_campaign_variants do |t|
      t.references :unofficial_campaign_message, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.text :content, null: false
      t.timestamps
    end

    create_table :unofficial_campaign_contacts do |t|
      t.references :unofficial_campaign, null: false, foreign_key: true
      t.references :contact, foreign_key: true
      t.string :name
      t.string :phone_number, null: false
      t.integer :status, null: false, default: 0
      t.string :source, null: false, default: 'system'
      t.bigint :sender_inbox_id
      t.integer :current_position, null: false, default: 0
      t.datetime :next_send_at
      t.datetime :sent_at
      t.integer :attempts, null: false, default: 0
      t.text :last_error
      t.timestamps
    end
    add_index :unofficial_campaign_contacts, [:unofficial_campaign_id, :phone_number], unique: true,
                                                                                       name: 'index_unofficial_campaign_contacts_on_campaign_phone'
    add_index :unofficial_campaign_contacts, :status

    create_table :campaign_opt_out_keywords do |t|
      t.references :account, null: false, foreign_key: true
      t.string :word, null: false
      t.timestamps
    end
    add_index :campaign_opt_out_keywords, [:account_id, :word], unique: true

    add_column :contacts, :campaign_opt_out, :boolean, null: false, default: false
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/MethodLength
