module ActionCableVisibilityHelpers
  def conversation_visibility_changed(event)
    conversation, account = extract_conversation_and_account(event)
    tokens = user_tokens(account, conversation.inbox.members)

    broadcast(account, tokens, Events::Types::CONVERSATION_VISIBILITY_CHANGED, conversation.push_event_data)
  end

  private

  def conversation_tokens(account, conversation)
    members = conversation.restricted? ? [conversation.private_owner].compact : conversation.inbox.members
    user_tokens(account, members)
  end

  def typing_event_listener_tokens(account, conversation, user)
    current_user_token = if user.is_a?(Contact)
                           conversation.contact_inbox.pubsub_token
                         elsif user.respond_to?(:pubsub_token)
                           user.pubsub_token
                         end

    tokens = conversation_tokens(account, conversation) + [conversation.contact_inbox.pubsub_token]
    current_user_token.present? ? tokens - [current_user_token] : tokens
  end
end
