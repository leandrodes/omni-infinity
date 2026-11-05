class Api::V1::Accounts::CannedResponsesController < Api::V1::Accounts::BaseController
  before_action :ensure_administrator, only: [:create, :update, :destroy]
  before_action :fetch_canned_response, only: [:update, :destroy]

  def index
    render json: canned_responses
  end

  def create
    @canned_response = Current.account.canned_responses.new(canned_response_attributes)
    assign_teams(@canned_response)
    @canned_response.save!
    render json: @canned_response
  end

  def update
    @canned_response.assign_attributes(canned_response_attributes)
    assign_teams(@canned_response)
    @canned_response.save!
    render json: @canned_response
  end

  def destroy
    @canned_response.destroy!
    head :ok
  end

  private

  def fetch_canned_response
    @canned_response = Current.account.canned_responses.find(params[:id])
  end

  def canned_response_params
    params.require(:canned_response).permit(
      :short_code, :content, :message_type, :available_for_all_teams
    )
  end

  def canned_response_attributes
    canned_response_params
  end

  def requested_team_ids
    params.dig(:canned_response, :team_ids) || params[:team_ids]
  end

  def assign_teams(canned_response)
    if ActiveModel::Type::Boolean.new.cast(canned_response_params[:available_for_all_teams]) == true
      canned_response.team_ids = []
      return
    end

    team_ids = requested_team_ids
    return if team_ids.nil?

    canned_response.team_ids = Current.account.teams.where(id: team_ids).pluck(:id)
  end

  def ensure_administrator
    return if Current.account_user&.administrator?

    render json: { error: 'Only administrators can manage canned responses' }, status: :forbidden
  end

  def canned_responses
    if params[:search]
      search = params[:search].delete("\0")
      Current.account.canned_responses
             .where('short_code ILIKE :search OR content ILIKE :search', search: "%#{search}%")
             .order_by_search(search)

    else
      Current.account.canned_responses
    end
  end
end
