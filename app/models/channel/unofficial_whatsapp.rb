# == Schema Information
#
# Table name: channel_unofficial_whatsapp
#
#  id                :bigint           not null, primary key
#  connection_status :string           default("initial"), not null
#  identifier        :string
#  instance_token    :text
#  phone_number      :string
#  provider          :string           default("wuzapi"), not null
#  provider_config   :jsonb            default({}), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :integer          not null
#
# Indexes
#
#  index_channel_unofficial_whatsapp_on_account_id  (account_id)
#  index_channel_unofficial_whatsapp_on_identifier  (identifier) UNIQUE
#

class Channel::UnofficialWhatsapp < ApplicationRecord
  include Channelable

  self.table_name = 'channel_unofficial_whatsapp'
  EDITABLE_ATTRS = [:phone_number, :provider, { provider_config: {} }].freeze

  has_secure_token :identifier

  PROVIDERS = %w[wuzapi].freeze
  CONNECTION_STATUSES = %w[initial connecting connected failed disconnected].freeze

  encrypts :instance_token if Chatwoot.encryption_configured?

  validates :provider, inclusion: { in: PROVIDERS }
  validates :connection_status, inclusion: { in: CONNECTION_STATUSES }

  def name
    'WhatsApp Não Oficial'
  end

  def provider_service
    case provider
    when 'wuzapi'
      UnofficialWhatsapp::Providers::WuzapiService.new(channel: self)
    else
      raise "Unknown unofficial WhatsApp provider: #{provider}"
    end
  end

  delegate :send_message, to: :provider_service
end
