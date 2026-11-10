class Conversations::PermissionFilterService
  attr_reader :conversations, :user, :account

  def initialize(conversations, user, account, plan_hint_selective_filter: false)
    @conversations = conversations
    @user = user
    @account = account
    @plan_hint_selective_filter = plan_hint_selective_filter
  end

  def perform
    return conversations if user_role == 'administrator'

    accessible_conversations
  end

  private

  def accessible_conversations
    return hinted_accessible_conversations if @plan_hint_selective_filter

    scope = conversations.where(inbox: user.inboxes.where(account_id: account.id))
                         .or(conversations.where(visibility: Conversation.visibilities[:restricted],
                                                 private_owner_id: user.id))
                         .or(participant_conversations)
    apply_visibility_filters(apply_private_visibility(scope))
  end

  def apply_private_visibility(scope)
    scope.where(
      'conversations.visibility != :restricted OR conversations.private_owner_id = :user_id',
      restricted: Conversation.visibilities[:restricted],
      user_id: user.id
    )
  end

  def apply_visibility_filters(scope)
    scope = apply_assigned_visibility(scope)
    apply_team_visibility(scope)
  end

  def apply_assigned_visibility(scope)
    return scope unless (account.settings || {})['hide_conversations_assigned_to_others']

    user_id = user.id
    conditions = ['conversations.assignee_id IS NULL', 'conversations.assignee_id = :user_id',
                  'conversations.visibility = :restricted',
                  'conversations.id IN (:participant_conversation_ids)',
                  'conversations.assignee_agent_bot_id IS NOT NULL']

    conditions << 'conversations.status = :resolved_status' unless (account.settings || {})['hide_resolved_conversations_assigned_to_others']

    scope.where(
      "(#{conditions.join(' OR ')})",
      user_id: user_id,
      resolved_status: Conversation.statuses[:resolved],
      restricted: Conversation.visibilities[:restricted],
      participant_conversation_ids: participant_conversation_ids
    )
  end

  # rubocop:disable Metrics/MethodLength
  def apply_team_visibility(scope)
    return scope unless (account.settings || {})['show_conversations_only_from_user_teams']

    team_ids = user.teams.where(account_id: account.id).pluck(:id)
    if team_ids.blank?
      return scope.where(
        [
          'conversations.visibility = :restricted',
          'conversations.id IN (:participant_conversation_ids)',
          'conversations.assignee_id = :user_id',
          'conversations.assignee_agent_bot_id IS NOT NULL'
        ].join(' OR '),
        restricted: Conversation.visibilities[:restricted],
        participant_conversation_ids: participant_conversation_ids,
        user_id: user.id
      )
    end

    scope.where(
      [
        'conversations.visibility = :restricted',
        'conversations.team_id IN (:team_ids)',
        'conversations.id IN (:participant_conversation_ids)',
        'conversations.assignee_id = :user_id',
        'conversations.assignee_agent_bot_id IS NOT NULL'
      ].join(' OR '),
      restricted: Conversation.visibilities[:restricted],
      team_ids: team_ids,
      participant_conversation_ids: participant_conversation_ids,
      user_id: user.id
    )
  end

  # rubocop:enable Metrics/MethodLength

  def participant_conversations
    conversations.where(id: ConversationParticipant.where(user_id: user.id).select(:conversation_id))
                 .where(inbox_id: user.inboxes.where(account_id: account.id).select(:id))
  end

  def participant_conversation_ids
    @participant_conversation_ids ||= ConversationParticipant.where(user_id: user.id).select(:conversation_id)
  end

  # Same rows as accessible_conversations. `inbox_id + 0` keeps the planner from
  # driving the query through an inbox scan, which it grossly misestimates when a
  # highly selective filter (e.g. labels) is present on large accounts (CW-7787).
  def hinted_accessible_conversations
    scope = conversations.where(
      '(conversations.inbox_id + 0) IN (
        SELECT inbox_members.inbox_id FROM inbox_members
        INNER JOIN inboxes ON inboxes.id = inbox_members.inbox_id
        WHERE inbox_members.user_id = :user_id AND inboxes.account_id = :account_id
      )',
      user_id: user.id, account_id: account.id
    ).or(conversations.where(visibility: Conversation.visibilities[:restricted],
                             private_owner_id: user.id))
                         .or(participant_conversations)
    apply_visibility_filters(apply_private_visibility(scope))
  end

  def account_user
    AccountUser.find_by(account_id: account.id, user_id: user.id)
  end

  def user_role
    account_user&.role
  end
end

Conversations::PermissionFilterService.prepend_mod_with('Conversations::PermissionFilterService')
