require 'rails_helper'

describe Messages::MentionService do
  let!(:account) { create(:account) }
  let!(:user) { create(:user, account: account) }
  let!(:first_agent) { create(:user, account: account) }
  let!(:second_agent) { create(:user, account: account) }
  let!(:inbox) { create(:inbox, account: account) }
  let!(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: user) }
  let!(:team) { create(:team, account: account) }

  before do
    create(:inbox_member, user: first_agent, inbox: inbox)
    create(:inbox_member, user: second_agent, inbox: inbox)
    create(:team_member, user: first_agent, team: team)
  end

  describe '#perform' do
    it 'does not process public messages' do
      message = build(:message, conversation: conversation, account: account,
                                content: "hi (mention://user/#{first_agent.id}/#{first_agent.name})", private: false)

      described_class.new(message: message).perform

      expect(conversation.conversation_participants.map(&:user_id)).not_to include(first_agent.id)
    end

    it 'adds mentioned users as participants and notifies them' do
      message = build(:message, conversation: conversation, account: account, sender: user,
                                content: "hi (mention://user/#{first_agent.id}/#{first_agent.name})", private: true)

      expect { described_class.new(message: message).perform }
        .to change(Notification, :count).by(1)
      expect(conversation.conversation_participants.map(&:user_id)).to include(first_agent.id)
      expect(first_agent.notifications.last.notification_type).to eq('conversation_participant_added')
    end

    it 'does not notify an existing participant again' do
      create(:conversation_participant, conversation: conversation, user: first_agent)
      message = build(:message, conversation: conversation, account: account, sender: user,
                                content: "hi (mention://user/#{first_agent.id}/#{first_agent.name})", private: true)

      expect { described_class.new(message: message).perform }
        .not_to change(Notification, :count)
    end

    it 'ignores team mentions' do
      message = build(:message, conversation: conversation, account: account,
                                content: "hi (mention://team/#{team.id}/#{team.name})", private: true)

      described_class.new(message: message).perform

      expect(conversation.conversation_participants.map(&:user_id)).not_to include(first_agent.id)
    end

    it 'ignores users outside the inbox' do
      outsider = create(:user, account: account)
      message = build(:message, conversation: conversation, account: account,
                                content: "hi (mention://user/#{outsider.id}/#{outsider.name})", private: true)

      described_class.new(message: message).perform

      expect(conversation.conversation_participants.map(&:user_id)).not_to include(outsider.id)
    end
  end
end
