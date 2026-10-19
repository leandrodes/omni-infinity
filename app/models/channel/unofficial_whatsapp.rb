# == Schema Information
#
#  id                  :bigint           not null, primary key
#  block_calls         :boolean          default(TRUE), not null
#  call_block_message  :string           default("Este número está bloqueado para receber chamadas")
#  connection_status   :string           default("initial"), not null
#  identifier          :string
#  ignore_groups       :boolean          default(TRUE), not null
#  instance_token      :text
#  phone_number        :string
#  provider            :string           default("wuzapi"), not null
#  provider_config     :jsonb            default({}), not null
#  proxy_enabled       :boolean          default(FALSE), not null
#  proxy_url           :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :integer          not null
#
# Indexes
#
#  index_channel_unofficial_whatsapp_on_account_id  (account_id)
#  index_channel_unofficial_whatsapp_on_identifier  (identifier) UNIQUE
#

class Channel::UnofficialWhatsapp < ApplicationRecord
  include Channelable

  self.table_name = 'channel_unofficial_whatsapp'
  EDITABLE_ATTRS = [:phone_number, :provider, { provider_config: {} }, :ignore_groups, :block_calls, :call_block_message, :proxy_enabled, :proxy_url].freeze

  has_secure_token :identifier

  PROVIDERS = %w[wuzapi evolution uzapi].freeze
  CONNECTION_STATUSES = %w[initial connecting connected failed disconnected].freeze

  encrypts :instance_token if Chatwoot.encryption_configured?

  validates :provider, inclusion: { in: PROVIDERS }
  validates :connection_status, inclusion: { in: CONNECTION_STATUSES }

  after_update_commit :sync_proxy_to_provider, if: :saved_change_to_proxy_settings?

  def name
    'WhatsApp Não Oficial'
  end

  def provider_service
    case provider
    when 'wuzapi'
      UnofficialWhatsapp::Providers::WuzapiService.new(channel: self)
    when 'evolution', 'uzapi'
      raise "#{provider.titleize} provider is not implemented yet"
    else
      raise "Unknown unofficial WhatsApp provider: #{provider}"
    end
  end

  delegate :send_message, to: :provider_service

  def saved_change_to_proxy_settings?
    saved_change_to_proxy_enabled? || saved_change_to_proxy_url?
  end

  def sync_proxy_to_provider
    return unless instance_token.present?

    provider_service.apply_proxy(proxy_enabled, proxy_url)
  rescue StandardError => e
    Rails.logger.warn("UnofficialWhatsapp proxy sync failed: #{e.class}: #{e.message}")
  end
end
