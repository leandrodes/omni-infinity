class Notification::ClearConversationQueueNotificationsService
  pattr_initialize [:account!, :conversation!]

  QUEUE_NOTIFICATION_TYPES = %w[
    conversation_creation
    conversation_assignment
    assigned_conversation_new_message
  ].freeze

  def perform
    notifications.find_each do |notification|
      notification.update!(read_at: Time.current)
    end
  end

  private

  def notifications
    Notification.where(
      account: account,
      primary_actor: conversation,
      notification_type: QUEUE_NOTIFICATION_TYPES,
      read_at: nil
    )
  end
end
