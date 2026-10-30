require 'rails_helper'

describe Messages::NewMessageNotificationService do
  context 'when message is not notifiable' do
    it 'will not create notifications for activity messages' do
      message = build(:message, message_type: :activity)
      expect(NotificationBuilder).not_to receive(:new)
      described_class.new(message: message).perform
    end

    it 'will not create notifications for private messages' do
      message = build(:message, message_type: :outgoing, private: true)
      expect(NotificationBuilder).not_to receive(:new)
      described_class.new(message: message).perform
    end
  end

  context 'when message is notifiable' do
    let(:account) { create(:account) }
    let(:assignee) { create(:user, account: account) }
    let(:participant) { create(:user, account: account) }
    let(:inbox) { create(:inbox, account: account) }
    let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: assignee) }

    before do
      create(:inbox_member, inbox: inbox, user: assignee)
      create(:inbox_member, inbox: inbox, user: participant)
      create(:conversation_participant, conversation: conversation, user: participant)
    end

    it 'notifies the assignee' do
      message = create(:message, conversation: conversation, account: account)

      described_class.new(message: message).perform

      expect(assignee.notifications.where(notification_type: 'assigned_conversation_new_message',
                                          account: account, primary_actor: conversation, secondary_actor: message)).to exist
    end

    it 'does not notify participants about new messages; they are alerted through the participants badge' do
      message = create(:message, conversation: conversation, account: account, message_type: :incoming)

      described_class.new(message: message).perform

      expect(participant.notifications.where(notification_type: 'participating_conversation_new_message',
                                             account: account, primary_actor: conversation, secondary_actor: message)).not_to exist
    end
  end
end
