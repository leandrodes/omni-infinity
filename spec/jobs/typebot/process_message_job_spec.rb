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

    it 'assigns the conversation using the selected team algorithm after handoff' do
      agent_one = create(:user, account: account, role: :agent, availability: :online)
      agent_two = create(:user, account: account, role: :agent, availability: :online)
      create(:inbox_member, inbox: conversation.inbox, user: agent_one)
      create(:inbox_member, inbox: conversation.inbox, user: agent_two)
      create(:team_member, team: team, user: agent_one, priority_level: 1)
      create(:team_member, team: team, user: agent_two, priority_level: 2)
      team.update!(allow_auto_assign: true, auto_assignment_algorithm: :priority)
      allow(OnlineStatusTracker).to receive(:get_available_users).and_return(
        { agent_one.id.to_s => 'online', agent_two.id.to_s => 'online' }
      )

      job.send(:apply_assignments, conversation, "[[fila:#{team.id}]]")

      expect(conversation.reload.team).to eq(team)
      expect(conversation.assignee).to eq(agent_one)
    end

    it 'corrects a priority assignment when the lower level agent is free' do
      agent_one = create(:user, account: account, role: :agent, availability: :online)
      agent_two = create(:user, account: account, role: :agent, availability: :online)
      create(:inbox_member, inbox: conversation.inbox, user: agent_one)
      create(:inbox_member, inbox: conversation.inbox, user: agent_two)
      create(:team_member, team: team, user: agent_one, priority_level: 1)
      create(:team_member, team: team, user: agent_two, priority_level: 2)
      team.update!(allow_auto_assign: true, auto_assignment_algorithm: :priority)
      allow(OnlineStatusTracker).to receive(:get_available_users).and_return(
        { agent_one.id.to_s => 'online', agent_two.id.to_s => 'online' }
      )

      job.send(:apply_assignments, conversation, "[[fila:#{team.id}]]")
      conversation.update!(assignee: agent_two)
      job.send(:enforce_team_priority!, conversation, team)

      expect(conversation.reload.assignee).to eq(agent_one)
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
