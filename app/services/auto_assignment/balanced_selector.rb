class AutoAssignment::BalancedSelector
  pattr_initialize [:inbox!]

  def select_agent(available_agents)
    return nil if available_agents.blank?

    selected_member = available_agents.min_by do |agent_member|
      [active_conversation_count(agent_member), last_assignment_at(agent_member)]
    end
    selected_member&.user
  end

  private

  def active_conversation_count(agent_member)
    active_conversations(agent_member).count
  end

  def last_assignment_at(agent_member)
    active_conversations(agent_member).maximum(:created_at) ||
      assigned_conversations(agent_member).maximum(:created_at) ||
      Time.zone.at(0)
  end

  def active_conversations(agent_member)
    assigned_conversations(agent_member).where(status: [:open, :pending])
  end

  def assigned_conversations(agent_member)
    agent_member.user.assigned_conversations.where(inbox: inbox)
  end
end
