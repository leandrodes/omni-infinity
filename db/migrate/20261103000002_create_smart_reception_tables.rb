# rubocop:disable Metrics/AbcSize, Metrics/MethodLength
class CreateSmartReceptionTables < ActiveRecord::Migration[7.2]
  def change
    create_table :smart_reception_settings do |t|
      t.references :account, null: false, foreign_key: true
      t.references :inbox, null: false, foreign_key: true, index: { unique: true }
      t.string :name, null: false, default: 'Recepção Inteligente'
      t.string :provider, null: false, default: 'openai'
      t.string :model, null: false, default: 'gpt-4.1-mini'
      t.text :api_key
      t.decimal :temperature, precision: 2, scale: 1, null: false, default: 0.2
      t.integer :max_response_tokens, null: false, default: 500
      t.integer :max_history_messages, null: false, default: 20
      t.boolean :use_previous_conversations, null: false, default: false
      t.integer :min_wait_seconds, null: false, default: 5
      t.integer :max_wait_seconds, null: false, default: 20
      t.text :primary_prompt
      t.text :secondary_prompt
      t.bigint :label_id
      t.bigint :team_id
      t.boolean :read_help_center, null: false, default: false
      t.boolean :enabled, null: false, default: false
      t.timestamps
    end

    create_table :smart_reception_keyword_rules do |t|
      t.references :account, null: false, foreign_key: true
      t.references :smart_reception_setting, null: false, foreign_key: true, index: { name: 'index_smart_reception_rules_on_setting' }
      t.string :keywords, null: false
      t.string :action, null: false, default: 'transfer'
      t.bigint :team_id
      t.bigint :label_id
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end

    create_table :smart_reception_attachments do |t|
      t.references :account, null: false, foreign_key: true
      t.references :smart_reception_setting, null: false, foreign_key: true, index: { name: 'index_smart_reception_attachments_on_setting' }
      t.string :keywords
      t.string :caption
      t.timestamps
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/MethodLength
