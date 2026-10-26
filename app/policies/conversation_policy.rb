class ConversationPolicy < ApplicationPolicy
  def index?
    true
  end

  def destroy?
    administrator?
  end

  def show?
    return true if administrator? || agent_bot?
    return false unless agent_can_view_conversation?
    return false if hidden_assigned_conversation?
    return false if team_only_visibility? && !team_access?

    true
  end

  private

  def agent_can_view_conversation?
    inbox_access? || team_access?
  end

  def administrator?
    account_user&.administrator?
  end

  def agent_bot?
    user.is_a?(AgentBot)
  end

  def inbox_access?
    user.inboxes.where(account_id: account&.id).exists?(id: record.inbox_id)
  end

  def team_access?
    return false if record.team_id.blank?

    user.teams.where(account_id: account&.id).exists?(id: record.team_id)
  end

  def hidden_assigned_conversation?
    return false unless (account.settings || {})['hide_conversations_assigned_to_others']
    return false if record.assignee_id.blank?
    return false if record.assignee_id == user.id

    hide_resolved = (account.settings || {})['hide_resolved_conversations_assigned_to_others']
    return true if hide_resolved

    !record.resolved?
  end

  def team_only_visibility?
    (account.settings || {})['show_conversations_only_from_user_teams'] == true
  end

  def assigned_to_user?
    record.assignee_id == user.id
  end

  def participant?
    record.conversation_participants.exists?(user_id: user.id)
  end
end

ConversationPolicy.prepend_mod_with('ConversationPolicy')
