class Conversations::AssignmentTeamGuard
  def initialize(conversation, agent:, team:)
    @conversation = conversation
    @agent = agent
    @team = team
  end

  def invalid?
    return false unless account_visibility_enabled?
    return false if private_conversation?
    return false if team.blank? || agent.blank?
    return false unless agent.is_a?(User)
    return false if administrator?

    !team.members.exists?(id: agent.id)
  end

  def error_payload
    {
      error: 'agent_not_in_team',
      agent_id: agent&.id,
      agent_name: agent&.name,
      team_id: team&.id,
      team_name: team&.name
    }
  end

  private

  attr_reader :conversation, :agent, :team

  def account_visibility_enabled?
    settings = conversation.account.settings || {}
    settings['hide_conversations_assigned_to_others'] == true &&
      settings['show_conversations_only_from_user_teams'] == true
  end

  def private_conversation?
    conversation.respond_to?(:restricted?) && conversation.restricted?
  end

  def administrator?
    conversation.account.account_users.find_by(user_id: agent.id)&.administrator? == true
  end
end
