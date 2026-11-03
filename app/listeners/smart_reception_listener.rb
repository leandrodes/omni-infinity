# rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
class SmartReceptionListener < BaseListener
  def message_created(event)
    message = extract_message_and_account(event)[0]
    return unless message.incoming?
    return if message.content.blank?
    return if message.content_attributes&.dig('bot_response')

    conversation = message.conversation
    return unless conversation.account.feature_enabled?('saas_ai_smart_reception')

    setting = conversation.inbox.smart_reception_setting
    return unless setting&.enabled?
    return unless SmartReception::ConversationPolicy.available?(conversation)

    SmartReception::ResponseJob.set(wait: setting.min_wait_seconds.seconds).perform_later(conversation.id, message.id)
  end
end
# rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
