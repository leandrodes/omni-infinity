require 'rails_helper'

describe Notification::ClearConversationQueueNotificationsService do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:agent) { create(:user, account: account) }

  it 'marks queue notifications as read' do
    notification = create(
      :notification, account: account, user: agent, primary_actor: conversation,
                     notification_type: :conversation_assignment, read_at: nil
    )

    described_class.new(account: account, conversation: conversation).perform

    expect(notification.reload.read_at).to be_present
  end

  it 'keeps mention notifications unread' do
    notification = create(
      :notification, account: account, user: agent, primary_actor: conversation,
                     notification_type: :conversation_mention, read_at: nil
    )

    described_class.new(account: account, conversation: conversation).perform

    expect(notification.reload.read_at).to be_nil
  end
end
