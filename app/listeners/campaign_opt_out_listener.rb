class CampaignOptOutListener < BaseListener
  def message_created(event)
    message = extract_message_and_account(event)[0]
    return unless message.incoming?
    return if message.content.blank?

    words = CampaignOptOutKeyword.words_for(message.account)
    normalized = message.content.to_s.downcase
    return unless words.any? { |word| normalized.match?(/\b#{Regexp.escape(word)}\b/i) }

    contact = message.conversation.contact
    return if contact.blank?

    contact.update!(campaign_opt_out: true)
    UnofficialCampaignContact.where(contact_id: contact.id, status: [:pending, :processing])
                             .where.not(source: 'csv')
                             .find_each do |campaign_contact|
      campaign_contact.update!(status: :opted_out, last_error: I18n.t('unofficial_campaign.opt_out_message'))
    end
  end
end
