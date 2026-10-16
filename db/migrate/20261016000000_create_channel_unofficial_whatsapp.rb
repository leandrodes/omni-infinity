class CreateChannelUnofficialWhatsapp < ActiveRecord::Migration[7.2]
  def change
    create_table :channel_unofficial_whatsapp do |t|
      t.string :phone_number
      t.string :provider, null: false, default: 'wuzapi'
      t.jsonb :provider_config, null: false, default: {}
      t.text :instance_token
      t.string :connection_status, null: false, default: 'initial'
      t.string :identifier
      t.integer :account_id, null: false

      t.timestamps
    end

    add_index :channel_unofficial_whatsapp, :account_id
    add_index :channel_unofficial_whatsapp, :identifier, unique: true
  end
end
