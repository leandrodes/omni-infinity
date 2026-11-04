class Conversations::UnreadBadges
  attr_reader :account, :user

  def initialize(account:, user:)
    @account = account
    @user = user
  end

  def perform
    base_counts.merge(unattended_counts).merge(participating_counts).merge(pending_counts)
  end

  private

  def base_counts
    {
      open_mine_count: count(open_conversations.where(assignee_id: user.id)),
      open_team_count: count(open_team_conversations),
      chatbot_count: count(chatbot_conversations),
      ai_count: count(accessible_conversations.where(smart_reception_active: true).open),
      unassigned_count: count(open_conversations.unassigned)
    }
  end

  def unattended_counts
    {
      unattended_count: unattended_count,
      unattended_mine_count: count(unattended_base.where(assignee_id: user.id)),
      unattended_participating_count: count(participating_open_conversations.unattended)
    }
  end

  def participating_counts
    {
      participating_count: count(participating_open_conversations)
    }
  end

  def pending_counts
    {
      pending_count: count(pending_visible_conversations),
      pending_mine_count: count(pending_base.where(assignee_id: user.id)),
      pending_team_count: count(pending_team_conversations),
      pending_participating_count: count(participating_pending_conversations)
    }
  end

  def open_conversations = accessible_conversations.open

  def pending_base
    accessible_conversations.where(status: :pending)
                            .where('assignee_id IS NOT NULL OR assignee_agent_bot_id IS NULL')
  end

  def chatbot_conversations
    accessible_conversations.where(status: :pending).where.not(assignee_agent_bot_id: nil)
  end

  def open_team_conversations
    relation = open_conversations.where.not(assignee_id: nil)
    return relation if administrator? || !show_only_teams?

    relation.where(team_id: current_user_team_ids)
  end

  def unattended_base = open_conversations.unattended

  def unattended_count
    return count(unattended_base) unless hide_assigned_to_others?

    count(unattended_base.where(assignee_id: user.id)) + count(participating_open_conversations.unattended)
  end

  def pending_visible_conversations
    return pending_base if administrator? || !hide_assigned_to_others?

    pending_base.where(
      '(assignee_id = :user_id) OR (assignee_id IS NULL AND team_id IN (:team_ids))',
      user_id: user.id,
      team_ids: current_user_team_ids
    )
  end

  def participating_open_conversations
    open_conversations.joins(:conversation_participants)
                      .where(conversation_participants: { user_id: user.id })
                      .where(participant_not_assignee_condition, user_id: user.id)
                      .distinct
  end

  def pending_team_conversations
    relation = pending_base.where.not(team_id: nil)
    relation = relation.where('assignee_id IS NULL OR assignee_id = :user_id', user_id: user.id) if !administrator? && hide_assigned_to_others?
    return relation if administrator?

    relation.where(team_id: current_user_team_ids)
  end

  def participating_pending_conversations
    pending_base.joins(:conversation_participants)
                .where(conversation_participants: { user_id: user.id })
                .where(participant_not_assignee_condition, user_id: user.id)
                .distinct
  end

  def participant_not_assignee_condition
    'conversations.assignee_id IS NULL OR conversations.assignee_id != :user_id'
  end

  def accessible_conversations
    @accessible_conversations ||= Conversations::PermissionFilterService.new(
      account.conversations,
      user,
      account
    ).perform
  end

  def current_user_team_ids
    @current_user_team_ids ||= user.teams.where(account_id: account.id).pluck(:id)
  end

  def hide_assigned_to_others?
    (account.settings || {})['hide_conversations_assigned_to_others'] == true
  end

  def show_only_teams?
    (account.settings || {})['show_conversations_only_from_user_teams'] == true
  end

  def administrator?
    @administrator ||= account.account_users.find_by(user_id: user.id)&.administrator? == true
  end

  def count(relation) = relation.unscope(:order).count
end
