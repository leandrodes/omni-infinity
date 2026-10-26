class AutoAssignment::BalancedSelector
  pattr_initialize [:inbox!]

  def select_agent(available_agents)
    return nil if available_agents.blank?

    available_agents.min_by { |agent_member| active_conversation_count(agent_member) }
  end

  private

  def active_conversation_count(agent_member)
    agent_member.user.assigned_conversations.where(inbox: inbox, status: :open).count
  end
end
