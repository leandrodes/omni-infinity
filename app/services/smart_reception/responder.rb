class SmartReception::Responder
  attr_reader :setting, :conversation, :message

  def initialize(setting:, conversation:, message:)
    @setting = setting
    @conversation = conversation
    @message = message
  end

  def perform
    return :unavailable unless SmartReception::ConversationPolicy.available?(conversation)
    return :empty_message if message.content.blank?

    rule = matching_rule
    return apply_rule!(rule) if rule.present?

    builder = SmartReception::ContextBuilder.new(setting: setting, conversation: conversation)
    content = SmartReception::AiClient.new(setting).perform(messages: builder.messages)
    send_response!(content, builder.matched_attachments) == :cancelled ? :cancelled : :responded
  rescue SmartReception::AiClient::Error => e
    Rails.logger.error("[SmartReception] conversation #{conversation.id}: #{e.message}")
    :error
  end

  private

  def matching_rule
    setting.keyword_rules.enabled.find { |rule| rule.matches?(message.content) }
  end

  def apply_rule!(rule)
    apply_label(rule.label)
    if rule.action == 'resolve'
      conversation.update!(status: :resolved)
    else
      conversation.update!(
        team_id: rule.team_id,
        status: conversation.open? ? :pending : conversation.status,
        waiting_since: conversation.waiting_since || Time.current
      )
    end
    SmartReception::ConversationPolicy.mark_handoff!(conversation, team_id: rule.team_id, label_id: rule.label_id)
    :rule_applied
  end

  # rubocop:disable Metrics/AbcSize
  def send_response!(content, attachments)
    conversation.reload
    conversation.with_lock do
      conversation.reload
      return :cancelled unless setting.reload.enabled?
      return :cancelled unless SmartReception::ConversationPolicy.available?(conversation)
      return :cancelled if conversation.messages.outgoing.where(sender_type: 'User')
                                       .exists?(['created_at > ?', message.created_at])

      params = {
        content: content.truncate(150_000),
        message_type: :outgoing,
        content_attributes: { smart_reception: true }
      }
      params[:attachments] = attachments.map { |attachment| attachment.file.blob.signed_id } if attachments.any?
      SmartReception::ConversationPolicy.mark_active!(conversation)
      Messages::MessageBuilder.new(nil, conversation, params).perform
    end
    :sent
  end

  # rubocop:enable Metrics/AbcSize

  def apply_label(label)
    return if label.blank?

    conversation.label_list.add(label.title)
    conversation.save!
  end
end
