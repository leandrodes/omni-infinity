class Contacts::BlockService
  pattr_initialize [:contact!, :blocked!]

  def perform
    contact.update!(blocked: blocked) if contact.blocked? != blocked
    sync_whatsapp_providers
    true
  rescue StandardError => e
    Rails.logger.error("Contact block sync failed for contact #{contact.id}: #{e.class}: #{e.message}")
    false
  end

  private

  def sync_whatsapp_providers
    contact.contact_inboxes.includes(inbox: :channel).find_each do |contact_inbox|
      channel = contact_inbox.inbox.channel
      next unless channel.is_a?(Channel::UnofficialWhatsapp)

      phone_number = contact_inbox.source_id.presence || contact.phone_number
      next if phone_number.blank?

      sync_provider(channel, phone_number)
    end
  end

  def sync_provider(channel, phone_number)
    service = channel.provider_service
    response = blocked ? service.block_contact(phone_number) : service.unblock_contact(phone_number)
    return if response.respond_to?(:success?) && response.success?

    Rails.logger.warn(
      "Contact #{contact.id} #{blocked ? 'block' : 'unblock'} failed on #{channel.provider}: " \
      "#{response.respond_to?(:code) ? response.code : 'no response'}"
    )
  rescue StandardError => e
    Rails.logger.warn("Contact #{contact.id} #{blocked ? 'block' : 'unblock'} failed on #{channel.provider}: #{e.class}: #{e.message}")
  end
end
