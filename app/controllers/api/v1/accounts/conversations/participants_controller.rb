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
    notify_participants_added(participant_ids_to_add)
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
    notify_participants_added(participant_ids_to_add)
    handle_participants_removed(participant_ids_to_remove)
    @participants = @conversation.conversation_participants.reload
    render action: 'show'
  end

  def destroy
    participant_ids_to_remove = current_participant_ids & params[:user_ids]

    ActiveRecord::Base.transaction do
      params[:user_ids].map { |user_id| @conversation.conversation_participants.find_by(user_id: user_id)&.destroy }
    end
    notify_unread_count_change if participant_ids_to_remove.any?
    handle_participants_removed(participant_ids_to_remove)
    head :ok
  end

  def validate_join_permission
    return if current_account_administrator?
    return if (Current.account.settings || {})['agents_can_join_conversations_as_participant']

    return unless participant_ids.include?(Current.user.id)

    render json: { error: 'Joining conversations as participant is disabled for agents' }, status: :forbidden
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

  def notify_participants_added(user_ids)
    user_ids.each do |user_id|
      next if user_id == Current.user&.id

      user = Current.account.users.find_by(id: user_id)
      next if user.blank?

      NotificationBuilder.new(
        notification_type: 'conversation_participant_added',
        user: user,
        account: Current.account,
        primary_actor: @conversation
      ).perform
    end
  end

  def handle_participants_removed(user_ids)
    return if user_ids.blank?

    clear_participant_notifications(user_ids)
    Rails.configuration.dispatcher.dispatch(
      Events::Types::CONVERSATION_PARTICIPANT_REMOVED,
      Time.zone.now,
      conversation: @conversation,
      user_ids: user_ids
    )
  end

  def clear_participant_notifications(user_ids)
    Notification.where(
      account_id: Current.account.id,
      primary_actor: @conversation,
      user_id: user_ids,
      notification_type: %w[
        participating_conversation_new_message
        conversation_participant_added
        conversation_participant_removed
      ]
    ).find_each(&:destroy!)
  end

  def notify_unread_count_change
    return unless Current.account.feature_enabled?('conversation_unread_counts')
    return unless Current.account.feature_enabled?('unread_count_for_filters')

    Rails.configuration.dispatcher.dispatch(CONVERSATION_UNREAD_COUNT_CHANGED, Time.zone.now, conversation: @conversation)
  end
end
