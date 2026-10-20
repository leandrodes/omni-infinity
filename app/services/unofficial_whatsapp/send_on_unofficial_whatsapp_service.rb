class UnofficialWhatsapp::SendOnUnofficialWhatsappService < Base::SendOnChannelService
  private

  def channel_class
    Channel::UnofficialWhatsapp
  end

  def perform_reply
    message_id = channel.send_message(message.conversation.contact_inbox.source_id, message)
    return if message_id.blank?

    attributes = { source_id: message_id }
    if message.status == 'failed'
      attributes[:status] = :sent
      attributes[:external_error] = nil
    end
    message.update!(attributes)
  end
end
