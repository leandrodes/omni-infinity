require 'rails_helper'

RSpec.describe ConversationPolicy, type: :policy do
  subject { described_class }

  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:administrator_context) { { user: administrator, account: account, account_user: administrator.account_users.find_by(account: account) } }
  let(:agent_context) { { user: agent, account: account, account_user: agent.account_users.find_by(account: account) } }

  let(:conversation) { create(:conversation, account: account) }

  permissions :destroy? do
    context 'when user is an administrator' do
      it 'allows destroy' do
        expect(subject).to permit(administrator_context, conversation)
      end
    end

    context 'when user is an agent' do
      it 'denies destroy' do
        expect(subject).not_to permit(agent_context, conversation)
      end
    end
  end

  permissions :index? do
    context 'when user is authenticated' do
      it 'allows index' do
        expect(subject).to permit(agent_context, conversation)
      end
    end
  end

  permissions :show? do
    context 'when user is an administrator' do
      it 'allows access' do
        expect(subject).to permit(administrator_context, conversation)
      end
    end

    context 'when agent has inbox access' do
      let(:inbox) { create(:inbox, account: account) }
      let(:conversation) { create(:conversation, account: account, inbox: inbox) }

      before { create(:inbox_member, user: agent, inbox: inbox) }

      it 'allows access' do
        expect(subject).to permit(agent_context, conversation)
      end
    end

    context 'when agent has team access' do
      let(:team) { create(:team, account: account) }
      let(:conversation) { create(:conversation, :with_team, account: account, team: team) }

      before { create(:team_member, team: team, user: agent) }

      it 'allows access' do
        expect(subject).to permit(agent_context, conversation)
      end
    end

    context 'when agent lacks inbox and team access' do
      let(:conversation) { create(:conversation, account: account) }

      it 'denies access' do
        expect(subject).not_to permit(agent_context, conversation)
      end
    end

    context 'when agent is a participant' do
      let(:other_agent) { create(:user, account: account) }
      let(:other_team) { create(:team, account: account) }
      let(:conversation) do
        create(:conversation, account: account, assignee: other_agent, team: other_team)
      end

      before do
        account.update!(
          settings: {
            hide_conversations_assigned_to_others: true,
            show_conversations_only_from_user_teams: true
          }
        )
        create(:inbox_member, inbox: conversation.inbox, user: agent)
        create(:conversation_participant, conversation: conversation, user: agent)
      end

      it 'allows access despite being assigned to another user and outside the user team' do
        expect(subject).to permit(agent_context, conversation)
      end
    end

    context 'when team-only visibility is enabled and the conversation is assigned to the agent without a team' do
      let(:inbox) { create(:inbox, account: account) }
      let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: agent, team: nil) }

      before do
        account.update!(settings: { show_conversations_only_from_user_teams: true })
        create(:inbox_member, user: agent, inbox: inbox)
      end

      it 'allows access to the assigned agent' do
        expect(subject).to permit(agent_context, conversation)
      end
    end

    context 'when conversation is private' do
      let(:owner) { create(:user, account: account, role: :agent) }
      let(:owner_context) { { user: owner, account: account, account_user: owner.account_users.find_by(account: account) } }
      let(:conversation) do
        create(
          :conversation,
          account: account,
          visibility: :restricted,
          private_owner: owner
        )
      end

      it 'allows the private owner' do
        expect(subject).to permit(owner_context, conversation)
      end

      it 'denies other agents' do
        expect(subject).not_to permit(agent_context, conversation)
      end

      it 'allows administrators' do
        expect(subject).to permit(administrator_context, conversation)
      end
    end
  end
end
