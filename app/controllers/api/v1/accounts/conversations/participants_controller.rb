class Api::V1::Accounts::Conversations::ParticipantsController < Api::V1::Accounts::Conversations::BaseController
  include Events::Types

  before_action :validate_participant_ids, only: [:create, :update]
  before_action :validate_join_permission, only: [:create, :update]

  def show
    @participants = @conversation.conversation_participants
  end

  def create
    participant_ids_to_add = participants_to_be_added_ids

    ActiveRecord::Base.transaction do
      @participants = participant_ids_to_add.map { |user_id| @conversation.conversation_participants.find_or_create_by!(user_id: user_id) }
    end
    notify_unread_count_change if participant_ids_to_add.any?
  end

  def update
    participant_ids_to_add = participants_to_be_added_ids
    participant_ids_to_remove = participants_to_be_removed_ids
    changed_participant_ids = participant_ids_to_add + participant_ids_to_remove

    ActiveRecord::Base.transaction do
      participant_ids_to_add.each { |user_id| @conversation.conversation_participants.find_or_create_by!(user_id: user_id) }
      participant_ids_to_remove.each { |user_id| @conversation.conversation_participants.find_by(user_id: user_id)&.destroy }
    end
    notify_unread_count_change if changed_participant_ids.any?
    @participants = @conversation.conversation_participants.reload
    render action: 'show'
  end

  def destroy
    participant_ids_to_remove = current_participant_ids & params[:user_ids]

    ActiveRecord::Base.transaction do
      params[:user_ids].map { |user_id| @conversation.conversation_participants.find_by(user_id: user_id)&.destroy }
    end
    notify_unread_count_change if participant_ids_to_remove.any?
    head :ok
  end

  def validate_join_permission
    return if current_account_administrator?
    return if (Current.account.settings || {})['agents_can_join_conversations_as_participant']

    if participant_ids.include?(Current.user.id)
      render json: { error: 'Joining conversations as participant is disabled for agents' }, status: :forbidden
    end
  end

  def current_account_administrator?
    Current.account.account_users.find_by(user_id: Current.user.id)&.administrator? == true
  end

  private

  def participants_to_be_added_ids
    participant_ids - current_participant_ids
  end

  def participants_to_be_removed_ids
    current_participant_ids - participant_ids
  end

  def current_participant_ids
    @current_participant_ids ||= @conversation.conversation_participants.pluck(:user_id)
  end

  def participant_ids
    @participant_ids ||= params[:user_ids].map(&:to_i)
  end

  def validate_participant_ids
    invalid_ids = participants_to_be_added_ids - @conversation.inbox.assignable_agents.map(&:id)
    return if invalid_ids.empty?

    render json: { error: 'Invalid participant IDs' }, status: :unprocessable_entity
  end

  def notify_unread_count_change
    return unless Current.account.feature_enabled?('conversation_unread_counts')
    return unless Current.account.feature_enabled?('unread_count_for_filters')

    Rails.configuration.dispatcher.dispatch(CONVERSATION_UNREAD_COUNT_CHANGED, Time.zone.now, conversation: @conversation)
  end
end
