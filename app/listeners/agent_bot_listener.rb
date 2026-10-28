class AgentBotListener < BaseListener
  def conversation_resolved(event)
    conversation = extract_conversation_and_account(event)[0]
    # Automation rules may resolve the conversation before the bot should react.
    return if conversation.resolved?

    inbox = conversation.inbox
    event_name = __method__.to_s
    payload = conversation.webhook_data.merge(event: event_name)
    agent_bots_for(inbox, conversation).each { |agent_bot| process_webhook_bot_event(agent_bot, payload) }
  end

  def conversation_opened(event)
    conversation = extract_conversation_and_account(event)[0]
    inbox = conversation.inbox
    event_name = __method__.to_s
    payload = conversation.webhook_data.merge(event: event_name)
    agent_bots_for(inbox, conversation).each { |agent_bot| process_webhook_bot_event(agent_bot, payload) }
  end


  def conversation_updated(event)
    conversation = extract_conversation_and_account(event)[0]
    changed_attributes = extract_changed_attributes(event)
    inbox = conversation.inbox
    event_name = __method__.to_s
    payload = conversation.webhook_data.merge(event: event_name, changed_attributes: changed_attributes)
    agent_bots_for(inbox, conversation).each { |agent_bot| process_webhook_bot_event(agent_bot, payload) }
  end

  def message_created(event)
    message = extract_message_and_account(event)[0]
    inbox = message.inbox
    return unless message.webhook_sendable?
    return if message.conversation.resolved?
    return if chatbot_keyword_message?(message)
    return if skip_typebot_for_matching_automation?(message)

    method_name = __method__.to_s
    agent_bots_for(inbox, message.conversation).each { |agent_bot| process_message_event(method_name, agent_bot, message, event) }
  end

  def skip_typebot_for_matching_automation?(message)
    return false unless message.incoming?

    account = message.account
    return false if account.blank?

    AutomationRule.where(account_id: account.id, event_name: 'message_created', active: true, execution_delay: nil).any? do |rule|
      ::AutomationRules::ConditionsFilterService.new(rule, message.conversation, { message: message }).perform
    end
  rescue StandardError => e
    Rails.logger.error "Error checking automation rules before Typebot: #{e.message}"
    false
  end

  def conversation_status_changed(event)
    conversation = extract_conversation_and_account(event)[0]
    return if conversation.resolved?

    changed_attributes = extract_changed_attributes(event)
    inbox = conversation.inbox
    event_name = __method__.to_s
    payload = conversation.webhook_data.merge(event: event_name, changed_attributes: changed_attributes)
    agent_bots_for(inbox, conversation).each { |agent_bot| process_webhook_bot_event(agent_bot, payload) }
  end

  def message_updated(event)
    message = extract_message_and_account(event)[0]
    inbox = message.inbox
    return unless message.webhook_sendable?

    method_name = __method__.to_s
    agent_bots_for(inbox, message.conversation).each { |agent_bot| process_message_event(method_name, agent_bot, message, event) }
  end

  def webwidget_triggered(event)
    contact_inbox = event.data[:contact_inbox]
    inbox = contact_inbox.inbox
    event_name = __method__.to_s
    payload = contact_inbox.webhook_data.merge(event: event_name)
    payload[:event_info] = event.data[:event_info]
    agent_bots_for(inbox).each { |agent_bot| process_webhook_bot_event(agent_bot, payload) }
  end

  def chatbot_keyword_message?(message)
    conversation = message.conversation
    keywords = (conversation.account.settings || {})['chatbot_auto_resolve_keywords'] || []
    return false if keywords.blank?

    keywords.any? { |keyword| message.content.to_s.downcase.include?(keyword.to_s.downcase.strip) }
  end

  private

  def agent_bots_for(inbox, conversation = nil)
    bots = [active_inbox_agent_bot(inbox)]
    bots << conversation.ai_assignee if conversation&.assignee_type == 'AgentBot'

    bots.compact.uniq
  end

  def active_inbox_agent_bot(inbox)
    return unless inbox.agent_bot_inbox&.active?

    inbox.agent_bot
  end

  def process_message_event(method_name, agent_bot, message, _event)
    # Only webhook bots are supported
    payload = message.webhook_data.merge(event: method_name)
    process_webhook_bot_event(agent_bot, payload)
  end

  def process_webhook_bot_event(agent_bot, payload)
    return if agent_bot.outgoing_url.blank?

    AgentBots::WebhookJob.perform_later(agent_bot.outgoing_url, payload, :agent_bot_webhook,
                                        secret: agent_bot.secret, delivery_id: SecureRandom.uuid)
  end
end
