class SmartReception::ContextBuilder
  PREVIOUS_CONVERSATIONS_LIMIT = 3
  PREVIOUS_MESSAGES_LIMIT = 6
  HELP_CENTER_LIMIT = 5
  HELP_CENTER_CHAR_LIMIT = 8_000

  attr_reader :setting, :conversation

  def initialize(setting:, conversation:)
    @setting = setting
    @conversation = conversation
  end

  def messages
    [system_message] + history_messages
  end

  def matched_attachments
    latest_content = latest_incoming_message&.content.to_s
    return [] if latest_content.blank?

    setting.attachments.select { |attachment| attachment.matches?(latest_content) }
  end

  private

  def system_message
    {
      role: 'system',
      content: [
        setting.system_prompt,
        contact_context,
        help_center_context
      ].compact.join("\n\n")
    }
  end

  def contact_context
    contact = conversation.contact
    return if contact.blank?

    [
      'Contexto do contato:',
      "Nome: #{contact.name}",
      "E-mail: #{contact.email}",
      "Telefone: #{contact.phone_number}"
    ].reject { |line| line.end_with?(': ') }.join("\n")
  end

  def help_center_context
    return unless setting.read_help_center?
    return if latest_incoming_message&.content.blank?

    articles = conversation.account.articles.published.text_search(latest_incoming_message.content).limit(HELP_CENTER_LIMIT)
    return if articles.blank?

    content = articles.map do |article|
      "Título: #{article.title}\n#{article.description}\n#{article.content}"
    end.join("\n\n---\n\n").truncate(HELP_CENTER_CHAR_LIMIT)

    "Base de conhecimento da Central de Ajuda:\n#{content}"
  end

  def history_messages
    messages = current_conversation_messages
    messages = previous_conversation_messages + messages if setting.use_previous_conversations?
    messages.last(setting.max_history_messages)
  end

  def current_conversation_messages
    conversation.messages
                .where(message_type: %i[incoming outgoing], private: false)
                .where.not(content: [nil, ''])
                .order(:created_at)
                .last(setting.max_history_messages)
                .map { |message| format_message(message) }
  end

  def previous_conversation_messages
    conversations = conversation.contact.conversations
                                .where.not(id: conversation.id)
                                .where(status: :resolved)
                                .order(updated_at: :desc)
                                .limit(PREVIOUS_CONVERSATIONS_LIMIT)

    conversations.flat_map do |previous|
      previous.messages
              .where(message_type: %i[incoming outgoing], private: false)
              .where.not(content: [nil, ''])
              .order(:created_at)
              .last(PREVIOUS_MESSAGES_LIMIT)
              .map { |message| format_message(message) }
    end
  end

  def format_message(message)
    {
      role: message.incoming? ? 'user' : 'assistant',
      content: message.content_for_llm.presence || message.content.to_s
    }
  end

  def latest_incoming_message
    @latest_incoming_message ||= conversation.messages.incoming.where.not(content: [nil, '']).order(:created_at).last
  end
end
