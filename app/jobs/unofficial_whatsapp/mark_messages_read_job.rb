class UnofficialWhatsapp::MarkMessagesReadJob < ApplicationJob
  queue_as :low

  def perform(conversation_id, message_ids)
    conversation = Conversation.find_by(id: conversation_id)
    return if conversation.blank?

    channel = conversation.inbox&.channel
    return unless channel.is_a?(Channel::UnofficialWhatsapp)

    source_ids = Array(message_ids).compact_blank.uniq
    return if source_ids.empty?

    channel.provider_service.mark_messages_as_read(
      conversation.contact_inbox.source_id,
      source_ids
    )
  rescue StandardError => e
    Rails.logger.warn("[UnofficialWhatsapp] mark read failed for conversation #{conversation_id}: #{e.class}: #{e.message}")
  end
end
