class AutoAssignment::PrioritySelector
  pattr_initialize [:inbox!, :priority_levels]

  def select_agent(available_agents)
    free_agents = available_agents.select { |agent_member| active_conversation_count(agent_member).zero? }
    candidates = free_agents.any? ? free_agents : available_agents

    candidates.min_by do |agent_member|
      [
        priority_level(agent_member),
        last_activity_at(agent_member),
        agent_member.user_id
      ]
    end&.user
  end

  private

  def priority_level(agent_member)
    (priority_levels || {}).fetch(agent_member.user_id, agent_member.priority_level).to_i.clamp(1, 10)
  end

  def active_conversation_count(agent_member)
    agent_member.user.assigned_conversations.where(inbox: inbox, status: [:open, :pending]).count
  end

  def last_activity_at(agent_member)
    agent_member.user.assigned_conversations
                .where(inbox: inbox)
                .maximum(:last_activity_at) || Time.zone.at(0)
  end
end
