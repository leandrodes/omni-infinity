class Messages::MentionService
  pattr_initialize [:message!]

  def perform
    return unless valid_mention_message?(message)

    validated_mentioned_ids = filter_mentioned_ids_by_inbox
    return if validated_mentioned_ids.blank?

    add_mentioned_users_as_participants(validated_mentioned_ids)
  end

  private

  def valid_mention_message?(message)
    message.private? && message.content.present? && mentioned_ids.present?
  end

  def mentioned_ids
    message.content.scan(%r{\(mention://user/(\d+)/(.+?)\)}).map(&:first).uniq
  end

  def valid_mentionable_user_ids
    @valid_mentionable_user_ids ||= begin
      inbox = message.inbox
      inbox.account.administrators.pluck(:id) + inbox.members.pluck(:id)
    end
  end

  def filter_mentioned_ids_by_inbox
    mentioned_ids & valid_mentionable_user_ids.map(&:to_s)
  end

  def add_mentioned_users_as_participants(validated_mentioned_ids)
    validated_mentioned_ids.each do |user_id|
      participant = message.conversation.conversation_participants.find_or_create_by(user_id: user_id)
      notify_participant_added(user_id) if participant.previously_new_record?
    end
  end

  def notify_participant_added(user_id)
    return if user_id.to_i == message.sender_id

    user = message.account.users.find_by(id: user_id)
    return if user.blank?

    NotificationBuilder.new(
      notification_type: 'conversation_participant_added',
      user: user,
      account: message.account,
      primary_actor: message.conversation
    ).perform
  end
end
