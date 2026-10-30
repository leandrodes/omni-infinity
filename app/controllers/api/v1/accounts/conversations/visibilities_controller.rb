class Api::V1::Accounts::Conversations::VisibilitiesController < Api::V1::Accounts::Conversations::BaseController
  def update
    unless can_manage_privacy?
      render json: { error: 'not_authorized' }, status: :forbidden
      return
    end

    restricted = ActiveModel::Type::Boolean.new.cast(params[:restricted])
    Conversations::PrivacyService.new(
      conversation: @conversation,
      user: Current.user,
      restricted: restricted
    ).perform

    render json: {
      visibility: @conversation.visibility,
      private_owner_id: @conversation.private_owner_id
    }
  end

  private

  def can_manage_privacy?
    return true if Current.account_user&.administrator?
    return true if @conversation.assignee_id == Current.user&.id
    return true if @conversation.private_owner_id == Current.user&.id

    false
  end
end
