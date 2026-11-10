class Api::V1::Accounts::TeamMembersController < Api::V1::Accounts::BaseController
  before_action :fetch_team
  before_action :check_authorization
  before_action :validate_member_id_params, only: [:create, :update, :destroy]

  def index
    @team_members = @team.team_members.includes(:user)
  end

  def create
    ActiveRecord::Base.transaction do
      new_member_ids = members_to_be_added_ids
      @team.add_members(new_member_ids)
      @team_members = @team.team_members.includes(:user).where(user_id: new_member_ids)
    end
  end

  def update
    ActiveRecord::Base.transaction do
      @team.add_members(members_to_be_added_ids)
      @team.remove_members(members_to_be_removed_ids)

      update_priority_levels if params[:priorities].present?
    end
    @team_members = @team.team_members.includes(:user)
    render action: 'create'
  end

  def destroy
    ActiveRecord::Base.transaction do
      @team.remove_members(params[:user_ids])
    end
    head :ok
  end

  private

  def members_to_be_added_ids
    params[:user_ids] - current_members_ids
  end

  def members_to_be_removed_ids
    current_members_ids - params[:user_ids]
  end

  def current_members_ids
    @current_members_ids ||= @team.members.pluck(:id)
  end

  def update_priority_levels
    priorities = params.permit(priorities: {})[:priorities] || {}
    priorities.each do |user_id, priority_level|
      @team.team_members.find_by(user_id: user_id)&.update!(priority_level: priority_level)
    end
  end

  def fetch_team
    @team = Current.account.teams.find(params[:team_id])
  end

  def validate_member_id_params
    invalid_ids = params[:user_ids].map(&:to_i) - @team.account.user_ids

    render json: { error: 'Invalid User IDs' }, status: :unauthorized and return if invalid_ids.present?
  end
end
