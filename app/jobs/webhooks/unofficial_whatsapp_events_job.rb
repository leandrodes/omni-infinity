class Webhooks::UnofficialWhatsappEventsJob < ApplicationJob
  queue_as :default

  def perform(identifier: nil, payload: {})
    channel = Channel::UnofficialWhatsapp.find_by(identifier: identifier)
    return if channel.blank? || channel.inbox.blank?

    service = if channel.provider == 'evolution'
                UnofficialWhatsapp::EvolutionIncomingMessageService
              else
                UnofficialWhatsapp::IncomingMessageService
              end
    service.new(inbox: channel.inbox, params: payload).perform
  end
end
