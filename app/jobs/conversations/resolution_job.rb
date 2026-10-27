# rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Layout/LineLength
class Conversations::ResolutionJob < ApplicationJob
  queue_as :low

  def perform(account:)
    # limiting the number of conversations to be resolved to avoid any performance issues
    resolvable_conversations = conversation_scope(account).limit(Limits::BULK_ACTIONS_LIMIT)
    resolvable_conversations.each do |conversation|
      resolve_message = auto_resolve_message_for(conversation, account)
      if resolve_message.present?
        if conversation.can_reply?
          conversation.messages.create!(
            account_id: conversation.account_id,
            inbox_id: conversation.inbox_id,
            message_type: :outgoing,
            content: resolve_message
          )
        else
          content = I18n.t('conversations.activity.auto_resolve.not_sent_due_to_messaging_window')
          ::Conversations::ActivityMessageJob.perform_later(conversation, {
            account_id: conversation.account_id,
            inbox_id: conversation.inbox_id,
            message_type: :activity,
            content: content
          }) if content
        end
      end
      conversation.add_labels(account.auto_resolve_label) if account.auto_resolve_label.present?
      conversation.update!(status: :resolved)
    end
  end

  private

  def auto_resolve_message_for(conversation, account)
    if conversation.pending? && conversation.assignee_agent_bot_id.present? && account.chatbot_auto_resolve_after.present?
      account.chatbot_auto_resolve_message
    else
      account.auto_resolve_message
    end
  end

  def conversation_scope(account)
    scopes = []
    if account.auto_resolve_after.present?
      scopes << account.conversations.where(status: :open).where('last_activity_at < ?', account.auto_resolve_after.minutes.ago)
    end
    if account.chatbot_auto_resolve_after.present?
      scopes << account.conversations.where(status: :pending, assignee_agent_bot_id: account.agent_bots.select(:id)).where('last_activity_at < ?', account.chatbot_auto_resolve_after.minutes.ago)
    end
    base_scope = scopes.reduce { |result, scope| result.or(scope) } || account.conversations.none
    # Exclude orphan conversations where contact was deleted but conversation cleanup is pending
    base_scope.where.not(contact_id: nil)
  end
end

# rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Layout/LineLength
