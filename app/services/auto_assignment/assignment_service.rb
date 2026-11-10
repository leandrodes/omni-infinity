class AutoAssignment::AssignmentService
  pattr_initialize [:inbox!]

  def assign_conversation_now(conversation)
    return false unless assignable?(conversation, include_pending: true)

    agent = find_available_agent(conversation)
    return false unless agent

    assign_conversation(conversation, agent)
  end

  def perform_bulk_assignment(limit: 100)
    return 0 unless auto_assignment_allowed?

    conversations = unassigned_conversations(limit).to_a
    return 0 if conversations.empty?
    return 0 if inbox.available_agents.empty?

    assigned_count = 0
    conversations.each do |conversation|
      assigned_count += 1 if perform_for_conversation(conversation)
    end
    assigned_count
  end

  private

  def auto_assignment_allowed?
    inbox.auto_assignment_v2_enabled? &&
      inbox.enable_auto_assignment? &&
      !inbox.out_of_office?
  end

  def perform_for_conversation(conversation)
    return false unless assignable?(conversation)

    agent = find_available_agent(conversation)
    return false unless agent

    assign_conversation(conversation, agent)
  end

  def assignable?(conversation, include_pending: false)
    valid_status = conversation.status == 'open' || (include_pending && conversation.status == 'pending')
    valid_status && conversation.assignee_id.nil?
  end

  def unassigned_conversations(limit)
    scope = inbox.conversations.unassigned.open

    # Skip stale backlog with no activity beyond the age threshold
    policy = inbox.assignment_policy
    scope = apply_age_exclusions(scope, age_exclusion_hours(policy))

    # Apply conversation priority using assignment policy if available
    scope = if policy&.longest_waiting?
              scope.reorder(last_activity_at: :asc, created_at: :asc)
            else
              scope.reorder(created_at: :asc)
            end

    scope.limit(limit)
  end

  def age_exclusion_hours(policy)
    return policy.exclude_older_than_hours if policy

    AssignmentPolicy::DEFAULT_EXCLUDE_OLDER_THAN_HOURS
  end

  def apply_age_exclusions(scope, hours_threshold)
    return scope if hours_threshold.blank?

    hours = hours_threshold.to_i
    return scope unless hours.positive?

    # Use last_activity_at so reopened/active conversations aren't excluded by their original created_at
    scope.where('conversations.last_activity_at >= ?', hours.hours.ago)
  end

  def find_available_agent(conversation = nil)
    agents = filter_agents_by_team(inbox.available_agents, conversation)
    return nil if agents.nil?

    agents = filter_agents_by_rate_limit(agents)
    agents = eligible_agents_for_capacity(agents, conversation)
    return nil if agents.empty?

    selector_for(conversation).select_agent(agents)
  end

  def selector_for(conversation)
    algorithm, priority_levels = assignment_strategy(conversation&.team)

    case algorithm || 'balanced'
    when 'priority'
      AutoAssignment::PrioritySelector.new(inbox: inbox, priority_levels: priority_levels)
    when 'sequential'
      AutoAssignment::SequentialSelector.new(inbox: inbox, priority_levels: priority_levels)
    else
      AutoAssignment::BalancedSelector.new(inbox: inbox)
    end
  end

  def assignment_strategy(team)
    if team.present?
      [team.auto_assignment_algorithm, team.team_members.pluck(:user_id, :priority_level).to_h]
    else
      [inbox.assignment_policy&.assignment_order, inbox.inbox_members.pluck(:user_id, :priority_level).to_h]
    end
  end

  def eligible_agents_for_capacity(agents, conversation = nil)
    free_agents = agents.select { |agent_member| active_conversation_count(agent_member).zero? }
    return free_agents if free_agents.any?

    active_queue_count = active_queue_scope(conversation).count
    return [] if active_queue_count <= agents.count

    agents
  end

  def active_queue_scope(conversation)
    scope = conversation&.team.present? ? conversation.team.conversations : inbox.conversations
    scope.where(status: [:open, :pending])
  end

  def active_conversation_count(agent_member)
    agent_member.user.assigned_conversations.where(inbox: inbox, status: [:open, :pending]).count
  end

  def filter_agents_by_team(agents, conversation)
    return agents if conversation&.team_id.blank?

    team = conversation.team
    return nil if team.blank? || team.allow_auto_assign.blank?

    team_member_ids = team.members.ids
    agents.where(user_id: team_member_ids)
  end

  def filter_agents_by_rate_limit(agents)
    agents.select do |agent_member|
      rate_limiter = build_rate_limiter(agent_member.user)
      rate_limiter.within_limit?
    end
  end

  def assign_conversation(conversation, agent)
    return false unless claim_and_assign(conversation, agent)

    conversation.reload

    rate_limiter = build_rate_limiter(agent)
    rate_limiter.track_assignment(conversation)

    dispatch_assignment_event(conversation, agent)
    true
  end

  # Atomically claim the row so two bulk runs that overlap (the in-flight gate
  # is best-effort and can lapse on TTL) can't both assign the same conversation.
  def claim_and_assign(conversation, agent)
    Current.executed_by = inbox.assignment_policy || inbox

    Conversation.transaction do
      locked = inbox.conversations
                    .where(id: conversation.id).unassigned
                    .lock('FOR UPDATE SKIP LOCKED')
                    .first
      next false unless locked

      locked.update!(assignee: agent)
      true
    end
  ensure
    Current.executed_by = nil
  end

  def dispatch_assignment_event(conversation, agent)
    Rails.configuration.dispatcher.dispatch(
      Events::Types::ASSIGNEE_CHANGED,
      Time.zone.now,
      conversation: conversation,
      user: agent
    )
  end

  def build_rate_limiter(agent)
    AutoAssignment::RateLimiter.new(inbox: inbox, agent: agent)
  end
end

AutoAssignment::AssignmentService.prepend_mod_with('AutoAssignment::AssignmentService')
