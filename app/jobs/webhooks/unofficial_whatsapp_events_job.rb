class Webhooks::UnofficialWhatsappEventsJob < ApplicationJob
  queue_as :default

  def perform(identifier: nil, payload: {})
    channel = Channel::UnofficialWhatsapp.find_by(identifier: identifier)
    return if channel.blank? || channel.inbox.blank?

    UnofficialWhatsapp::IncomingMessageService.new(inbox: channel.inbox, params: payload).perform
  end
end
