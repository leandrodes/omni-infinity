class Api::V1::Accounts::Conversations::AssignmentsController < Api::V1::Accounts::Conversations::BaseController
  # assigns agent/team to a conversation
  def create
    if params.key?(:assignee_id) || agent_bot_assignment?
      set_agent
    elsif params.key?(:team_id)
      set_team
    else
      render json: nil
    end
  end

  private

  def set_agent
    target_team = assignment_team
    guard = Conversations::AssignmentTeamGuard.new(@conversation, agent: assignee, team: target_team)

    if guard.invalid?
      render json: guard.error_payload, status: :unprocessable_entity
      return
    end

    render_agent(assign_agent_to_team(target_team))
  end

  def assign_agent_to_team(target_team)
    ActiveRecord::Base.transaction do
      @conversation.update!(team: target_team) if params.key?(:team_id)
      resource = Conversations::AssignmentService.new(
        conversation: @conversation,
        assignee_id: params[:assignee_id],
        assignee_type: params[:assignee_type]
      ).perform
      create_assignment_note
      resource
    end
  end

  def create_assignment_note
    note = params[:note].to_s.strip
    return if note.blank?

    @conversation.messages.create!(
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      message_type: :outgoing,
      private: true,
      sender: Current.user,
      content: note
    )
  end

  def assignee
    return if agent_bot_assignment?

    Current.account.users.find_by(id: params[:assignee_id])
  end

  def assignment_team
    return @conversation.team unless params.key?(:team_id)

    team_id = params[:team_id].to_i
    team_id.positive? ? Current.account.teams.find_by(id: team_id) : nil
  end

  def render_agent(resource)
    case resource
    when User
      render partial: 'api/v1/models/agent', formats: [:json], locals: { resource: resource }
    when AgentBot
      render partial: 'api/v1/models/agent_bot_slim', formats: [:json], locals: { resource: resource }
    else
      render json: nil
    end
  end

  def set_team
    team_id = params[:team_id].to_i
    @team = team_id.positive? ? Current.account.teams.find(team_id) : nil
    @conversation.with_lock do
      @conversation.update!(team: @team)
    end
    render json: @team
  end

  def agent_bot_assignment?
    params[:assignee_type].to_s == 'AgentBot'
  end
end

Api::V1::Accounts::Conversations::AssignmentsController.prepend_mod_with(
  'Api::V1::Accounts::Conversations::AssignmentsController'
)
