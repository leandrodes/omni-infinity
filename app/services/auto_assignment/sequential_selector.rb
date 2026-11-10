class AutoAssignment::SequentialSelector
  pattr_initialize [:inbox!, :priority_levels]

  def select_agent(available_agents)
    free_agents = available_agents.select { |agent_member| active_conversation_count(agent_member).zero? }
    candidates = free_agents.any? ? free_agents : available_agents

    candidates.min_by do |agent_member|
      [priority_level(agent_member), agent_member.user_id]
    end&.user
  end

  private

  def priority_level(agent_member)
    (priority_levels || {}).fetch(agent_member.user_id, agent_member.priority_level).to_i
  end

  def active_conversation_count(agent_member)
    agent_member.user.assigned_conversations.where(inbox: inbox, status: [:open, :pending]).count
  end
end
