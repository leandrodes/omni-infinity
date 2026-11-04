class Inboxes::OutOfOfficeActionService
  pattr_initialize [:conversation!]

  def perform
    return unless inbox.out_of_office?
    return if recent_human_activity?

    case inbox.out_of_office_action
    when 'resolve'
      resolve_conversation
    when 'pending_team'
      move_to_pending_team
    when 'none'
      leave_unassigned
    end
  end

  private

  delegate :inbox, to: :conversation

  def recent_human_activity?
    conversation.messages.outgoing
                .where(private: false)
                .where.not(sender_type: 'AgentBot')
                .exists?(['created_at > ?', 5.minutes.ago])
  end

  def resolve_conversation
    conversation.update!(
      status: :resolved,
      assignee_id: nil,
      assignee_agent_bot_id: nil,
      ai_assignee_type: nil
    )
  end

  def leave_unassigned
    conversation.update!(
      team_id: nil,
      assignee_id: nil,
      assignee_agent_bot_id: nil,
      ai_assignee_type: nil,
      status: :pending,
      waiting_since: conversation.waiting_since || Time.current
    )
  end

  def move_to_pending_team
    team = inbox.out_of_office_team
    return if team.blank?

    conversation.update!(
      team_id: team.id,
      assignee_id: nil,
      assignee_agent_bot_id: nil,
      ai_assignee_type: nil,
      status: :pending,
      waiting_since: conversation.waiting_since || Time.current
    )
  end
end
