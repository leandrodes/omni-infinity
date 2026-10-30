class ClearConversationParticipants < ActiveRecord::Migration[7.2]
  PARTICIPANT_NOTIFICATION_TYPES = %w[
    participating_conversation_new_message
    conversation_participant_added
    conversation_participant_removed
  ].freeze

  def up
    ConversationParticipant.find_each(&:destroy!)

    Notification.where(notification_type: PARTICIPANT_NOTIFICATION_TYPES, read_at: nil)
                .update_all(read_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  def down
    # Data cleanup cannot be reversed.
  end
end
