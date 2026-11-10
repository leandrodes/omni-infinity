class AutoAssignment::BalancedSelector
  pattr_initialize [:inbox!]

  def select_agent(available_agents)
    return nil if available_agents.blank?

    available_agents.min_by do |agent_member|
      [active_conversation_count(agent_member), last_activity_at(agent_member), agent_member.user_id]
    end&.user
  end

  private

  def active_conversation_count(agent_member)
    assigned_conversations(agent_member).where(status: [:open, :pending]).count
  end

  def last_activity_at(agent_member)
    assigned_conversations(agent_member).maximum(:last_activity_at) || Time.zone.at(0)
  end

  def assigned_conversations(agent_member)
    agent_member.user.assigned_conversations.where(inbox: inbox)
  end
end
