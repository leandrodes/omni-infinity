require 'rails_helper'

RSpec.describe Typebot::ProcessMessageJob do
  subject(:job) { described_class.new }

  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:agent_bot) { create(:agent_bot, account: account) }
  let(:conversation) { create(:conversation, account: account, status: :pending, ai_assignee: agent_bot) }

  describe '#apply_assignments' do
    it 'routes the conversation to a team while keeping the bot active' do
      content = job.send(:apply_assignments, conversation, "[[fila:#{team.id}, manter_bot:1]]")

      expect(content).to be_blank
      expect(conversation.reload.team).to eq(team)
      expect(conversation.assignee_agent_bot_id).to eq(agent_bot.id)
      expect(conversation.custom_attributes[Typebot::ConversationPolicy::BOT_TEAM_KEY]).to eq(team.id)
      expect(Typebot::ConversationPolicy.bot_enabled?(conversation)).to be(true)
    end

    it 'transfers the conversation and stops the bot without the keep-bot flag' do
      content = job.send(:apply_assignments, conversation, "[[fila:#{team.id}]]")

      expect(content).to be_blank
      expect(conversation.reload.team).to eq(team)
      expect(conversation.assignee_agent_bot_id).to be_nil
      expect(conversation.custom_attributes[Typebot::ConversationPolicy::HANDOFF_KEY]).to be(true)
      expect(Typebot::ConversationPolicy.bot_enabled?(conversation)).to be(false)
    end

    it 'keeps the surrounding text and accepts the keep-bot flag after the team' do
      content = job.send(:apply_assignments, conversation, "Encaminhando... [[fila:#{team.id}, manter_bot]]")

      expect(content).to eq('Encaminhando...')
      expect(conversation.reload.team).to eq(team)
    end

    it 'notifies the agent assigned by the bot' do
      agent = create(:user, account: account, role: :agent)
      create(:inbox_member, inbox: conversation.inbox, user: agent)

      perform_enqueued_jobs do
        job.send(:apply_assignments, conversation, "[[agente:#{agent.id}]]")
      end

      expect(conversation.reload.assignee).to eq(agent)
      expect(agent.notifications.where(notification_type: 'conversation_assignment',
                                       account: account, primary_actor: conversation)).to exist
    end
  end
end
