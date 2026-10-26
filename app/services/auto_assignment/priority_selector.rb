class AutoAssignment::PrioritySelector
  pattr_initialize [:inbox!, :team]

  def select_agent(available_agents)
    return nil if available_agents.blank?

    available_agents.group_by { |agent_member| priority_level(agent_member) }.sort.each do |_level, agents|
      zero_load_agents = agents.select { |agent_member| active_conversation_count(agent_member).zero? }
      return zero_load_agents.min_by { |agent_member| active_conversation_count(agent_member) } if zero_load_agents.any?
    end

    nil
  end

  private

  def priority_level(agent_member)
    return 1 if team.blank?

    team.team_members.find_by(user_id: agent_member.user_id)&.priority_level || 1
  end

  def active_conversation_count(agent_member)
    agent_member.user.assigned_conversations.where(inbox: inbox, status: :open).count
  end
end
