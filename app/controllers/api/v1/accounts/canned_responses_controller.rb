class Api::V1::Accounts::CannedResponsesController < Api::V1::Accounts::BaseController
  before_action :ensure_administrator, only: [:create, :update, :destroy]
  before_action :fetch_canned_response, only: [:update, :destroy]

  def index
    render json: canned_responses
  end

  def create
    @canned_response = Current.account.canned_responses.new(canned_response_attributes)
    assign_inboxes(@canned_response)
    @canned_response.save!
    render json: @canned_response
  end

  def update
    @canned_response.assign_attributes(canned_response_attributes)
    assign_inboxes(@canned_response)
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
      :short_code, :content, :message_type, :available_for_all_inboxes
    )
  end

  def canned_response_attributes
    canned_response_params
  end

  def requested_inbox_ids
    params.dig(:canned_response, :inbox_ids) || params[:inbox_ids]
  end

  def assign_inboxes(canned_response)
    if ActiveModel::Type::Boolean.new.cast(canned_response_params[:available_for_all_inboxes]) == true
      canned_response.inbox_ids = []
      return
    end

    inbox_ids = requested_inbox_ids
    return if inbox_ids.nil?

    canned_response.inbox_ids = Current.account.inboxes.where(id: inbox_ids).pluck(:id)
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
