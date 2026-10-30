require 'rails_helper'

RSpec.describe Typebot::ConversationPolicy do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:agent_bot) { create(:agent_bot, account: account) }
  let(:conversation) { create(:conversation, account: account, status: :pending, ai_assignee: agent_bot) }

  describe '.bot_enabled?' do
    it 'is enabled for a pending bot conversation without a team' do
      expect(described_class.bot_enabled?(conversation)).to be(true)
    end

    it 'is enabled when the conversation is routed to the bot team' do
      described_class.mark_bot_team!(conversation, team.id)

      expect(described_class.bot_enabled?(conversation.reload)).to be(true)
    end

    it 'is disabled when the conversation has a team without the bot routing marker' do
      conversation.update!(team: team)

      expect(described_class.bot_enabled?(conversation.reload)).to be(false)
    end

    it 'is disabled after a handoff' do
      described_class.mark_handoff!(conversation, team_id: team.id)

      expect(described_class.bot_enabled?(conversation.reload)).to be(false)
    end

    it 'is disabled when a human agent is assigned' do
      conversation.update!(assignee: create(:user, account: account))

      expect(described_class.bot_enabled?(conversation.reload)).to be(false)
    end
  end
end
