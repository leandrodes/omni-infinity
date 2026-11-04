# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
class UnofficialCampaigns::ContactJob < ApplicationJob
  queue_as :default

  def perform(campaign_id, campaign_contact_id)
    campaign = UnofficialCampaign.find_by(id: campaign_id)
    contact = campaign&.contacts&.find_by(id: campaign_contact_id)
    return unless campaign&.running? && contact
    return unless contact.pending? || contact.processing?
    return contact.mark_opted_out! if contact.opted_out?

    unless campaign.allowed_now?
      next_time = campaign.next_allowed_time
      contact.update!(next_send_at: next_time)
      self.class.set(wait: [next_time - Time.current, 1].max).perform_later(campaign.id, contact.id)
      return
    end

    prepare_contact!(campaign, contact)
    message = campaign.messages.ordered.find_by(position: contact.current_position)
    if message.blank?
      finish_contact!(campaign, contact)
      return
    end

    send_message!(campaign, contact, message)
    contact.update!(current_position: contact.current_position + 1)
    if campaign.messages.ordered.exists?(['position > ?', message.position])
      wait = campaign.random_between(message.wait_min_seconds, message.wait_max_seconds)
      self.class.set(wait: wait.seconds).perform_later(campaign.id, contact.id)
    else
      finish_contact!(campaign, contact)
    end
  rescue StandardError => e
    handle_failure(campaign, contact, e)
  end

  private

  def prepare_contact!(campaign, contact)
    return if contact.sender_inbox_id.present?

    inbox = campaign.next_sender_inbox
    contact.update!(sender_inbox_id: inbox&.id, status: :processing)
  end

  def send_message!(campaign, contact, message)
    inbox = contact.sender_inbox || campaign.next_sender_inbox
    raise 'Nenhuma caixa de entrada remetente disponível' if inbox.blank?

    contact.update!(sender_inbox_id: inbox.id, status: :processing)
    variant = message.variants.order(Arel.sql('RANDOM()')).first
    raise 'Nenhuma versão de mensagem configurada' if variant.blank?

    message_record = Messages::MessageBuilder.new(
      nil,
      conversation_for!(campaign, contact, inbox),
      {
        content: variant.content,
        message_type: :outgoing,
        attachments: variant.attachments.map { |attachment| attachment.blob.signed_id },
        content_attributes: { unofficial_campaign_id: campaign.id }
      }
    ).perform
    contact.update!(attempts: contact.attempts + 1, last_error: nil)
    [message_record, variant]
  end

  def conversation_for!(campaign, contact, inbox)
    contact_record = contact.contact ||
                     campaign.account.contacts.find_or_create_by!(phone_number: contact.phone_number) do |record|
                       record.name = contact.name.presence || contact.phone_number
                     end
    contact.update!(contact: contact_record) if contact.contact_id.blank?

    contact_inbox = ContactInboxBuilder.new(
      contact: contact_record,
      inbox: inbox,
      source_id: contact.phone_jid
    ).perform
    raise 'Não foi possível criar o contato na caixa de entrada' if contact_inbox.blank?

    ConversationBuilder.new(
      params: ActionController::Parameters.new({ status: 'open' }),
      contact_inbox: contact_inbox
    ).perform
  end

  def finish_contact!(campaign, contact)
    contact.update!(status: :sent, sent_at: Time.current, next_send_at: nil)
    apply_post_action!(campaign, contact)
    campaign.mark_completed_if_done!
    schedule_next_contact!(campaign)
  end

  def schedule_next_contact!(campaign)
    next_contact = campaign.contacts.pending.order(:id).first
    unless next_contact
      campaign.mark_completed_if_done!
      return
    end

    delay = campaign.next_contact_delay
    target = Time.current + delay.seconds
    target = campaign.next_allowed_time(target) unless campaign.allowed_now?(target)
    next_contact.update!(next_send_at: target)
    self.class.set(wait: [target - Time.current, 1].max).perform_later(campaign.id, next_contact.id)
  end

  def apply_post_action!(campaign, contact)
    conversation = contact.contact&.conversations&.where(inbox_id: contact.sender_inbox_id)&.order(updated_at: :desc)&.first
    return if conversation.blank?

    case campaign.post_action
    when 'resolve'
      conversation.update!(status: :resolved)
    when 'pending_team'
      conversation.update!(team_id: campaign.post_team_id, status: :pending, assignee_id: nil,
                           assignee_agent_bot_id: nil, ai_assignee_type: nil,
                           waiting_since: conversation.waiting_since || Time.current)
    when 'assign_team'
      conversation.update!(team_id: campaign.post_team_id, status: :open, assignee_id: nil)
    when 'assign_team_agent'
      conversation.update!(team_id: campaign.post_team_id, assignee_id: campaign.post_agent_id, status: :open)
    end
  end

  def handle_failure(campaign, contact, error)
    return unless contact

    contact.update!(status: :failed, last_error: error.message, attempts: contact.attempts + 1)
    Rails.logger.error("[UnofficialCampaign] campaign #{campaign&.id} contact #{contact.id}: #{error.class}: #{error.message}")
    schedule_next_contact!(campaign) if campaign&.running?
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
