class Conversations::PrivacyService
  def initialize(conversation:, user:, restricted:)
    @conversation = conversation
    @user = user
    @restricted = restricted
  end

  def perform
    if restricted
      enable_privacy
    else
      disable_privacy
    end

    conversation.reload
  end

  private

  attr_reader :conversation, :user, :restricted

  def enable_privacy
    ActiveRecord::Base.transaction do
      Conversations::AssignmentService.new(
        conversation: conversation,
        assignee_id: user.id
      ).perform
      conversation.update!(visibility: :restricted, private_owner_id: user.id)
    end
  end

  def disable_privacy
    conversation.update!(visibility: :shared, private_owner_id: nil)
  end
end
