class BulkActionsJob < ApplicationJob
  include DateRangeHelper

  queue_as :medium
  attr_accessor :records

  MODEL_TYPE = ['Conversation'].freeze

  def perform(account:, params:, user:)
    @account = account
    @user = user
    Current.user = user
    @params = params
    @records = records_to_updated(params[:ids])
    bulk_update
  ensure
    Current.reset
  end

  def bulk_update
    bulk_remove_labels
    bulk_conversation_update
  end

  def bulk_conversation_update
    params = available_params(@params)&.to_h&.with_indifferent_access
    records.each do |conversation|
      bulk_add_labels(conversation)
      bulk_snoozed_until(conversation)
      update_params = assignment_safe_params(conversation, params)
      update_params = transfer_private_owner(conversation, update_params)
      conversation.update(update_params) if update_params.present?
      create_assignment_note(conversation) if update_params.present? && @params[:note].present?
    end
  end

  def assignment_safe_params(conversation, params)
    return params if params.blank? || params[:assignee_id].blank?

    team = assignment_team(conversation, params)
    agent = @account.users.find_by(id: params[:assignee_id])
    guard = Conversations::AssignmentTeamGuard.new(conversation, agent: agent, team: team)

    if guard.invalid?
      Rails.logger.warn(
        "[BulkActions] skipped assignment for conversation #{conversation.id}: #{guard.error_payload}"
      )
      return nil
    end

    params
  end

  def create_assignment_note(conversation)
    note = @params[:note].to_s.strip
    return if note.blank?

    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :outgoing,
      private: true,
      sender: @user,
      content: note
    )
  end

  def transfer_private_owner(conversation, params)
    return params unless conversation&.restricted? && params.present? && params[:assignee_id].present?

    params.merge(private_owner_id: params[:assignee_id])
  end

  def assignment_team(conversation, params)
    return conversation.team unless params.key?(:team_id)

    team_id = params[:team_id].to_i
    team_id.positive? ? @account.teams.find_by(id: team_id) : nil
  end

  def bulk_remove_labels
    records.each do |conversation|
      remove_labels(conversation)
    end
  end

  def available_params(params)
    return unless params[:fields]

    params[:fields].delete_if { |key, value| value.nil? && key == 'status' }
  end

  def bulk_add_labels(conversation)
    conversation.add_labels(@params[:labels][:add]) if @params[:labels] && @params[:labels][:add]
  end

  def bulk_snoozed_until(conversation)
    conversation.snoozed_until = parse_date_time(@params[:snoozed_until].to_s) if @params[:snoozed_until]
  end

  def remove_labels(conversation)
    return unless @params[:labels] && @params[:labels][:remove]

    labels = conversation.label_list - @params[:labels][:remove]
    conversation.update(label_list: labels)
  end

  def records_to_updated(ids)
    current_model = @params[:type].camelcase
    return unless MODEL_TYPE.include?(current_model)

    scope = current_model.constantize.where(account_id: @account.id, display_id: ids)
    Conversations::PermissionFilterService.new(scope, @user, @account).perform
  end
end
