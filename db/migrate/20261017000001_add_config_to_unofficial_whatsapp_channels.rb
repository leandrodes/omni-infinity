class AddConfigToUnofficialWhatsappChannels < ActiveRecord::Migration[7.2]
  def change
    add_column :channel_unofficial_whatsapp, :ignore_groups, :boolean, default: true, null: false
    add_column :channel_unofficial_whatsapp, :block_calls, :boolean, default: true, null: false
    add_column :channel_unofficial_whatsapp, :call_block_message, :string, default: 'Este número está bloqueado para receber chamadas'
    add_column :channel_unofficial_whatsapp, :proxy_enabled, :boolean, default: false, null: false
    add_column :channel_unofficial_whatsapp, :proxy_url, :string
  end
end
