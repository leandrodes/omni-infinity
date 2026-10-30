require 'rails_helper'

RSpec.describe Conversations::PermissionFilterService do
  let(:account) { create(:account) }
  let!(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let!(:another_conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:inbox) { create(:inbox, account: account) }

  # This inbox_member is used to establish the agent's access to the inbox
  before { create(:inbox_member, user: agent, inbox: inbox) }

  describe '#perform' do
    context 'when user is an administrator' do
      it 'returns all conversations' do
        result = described_class.new(
          account.conversations,
          admin,
          account
        ).perform

        expect(result).to include(conversation)
        expect(result).to include(another_conversation)
        expect(result.count).to eq(2)
      end
    end

    context 'when user is an agent' do
      it 'returns all conversations with no further filtering' do
        inbox_ids = agent.inboxes.where(account_id: account.id).pluck(:id)

        # The base implementation returns all conversations
        # expecting the caller to filter by assigned inboxes
        result = described_class.new(
          account.conversations.where(inbox_id: inbox_ids),
          agent,
          account
        ).perform

        expect(result).to include(conversation)
        expect(result).to include(another_conversation)
        expect(result.count).to eq(2)
      end
    end

    context 'when conversation is private' do
      let(:owner) { create(:user, account: account, role: :agent) }
      let(:other_agent) { create(:user, account: account, role: :agent) }
      let!(:private_conversation) do
        create(
          :conversation,
          account: account,
          inbox: inbox,
          visibility: :restricted,
          private_owner: owner
        )
      end

      before do
        create(:inbox_member, user: owner, inbox: inbox)
        create(:inbox_member, user: other_agent, inbox: inbox)
      end

      it 'returns the private conversation to its owner' do
        result = described_class.new(account.conversations, owner, account).perform

        expect(result).to include(private_conversation)
      end

      it 'hides the private conversation from other agents' do
        result = described_class.new(account.conversations, other_agent, account).perform

        expect(result).not_to include(private_conversation)
      end

      it 'returns the private conversation to administrators' do
        result = described_class.new(account.conversations, admin, account).perform

        expect(result).to include(private_conversation)
      end
    end

    context 'when user is a participant' do
      let(:other_agent) { create(:user, account: account, role: :agent) }
      let(:other_team) { create(:team, account: account) }

      before do
        account.update!(
          settings: {
            hide_conversations_assigned_to_others: true,
            show_conversations_only_from_user_teams: true
          }
        )
        create(:inbox_member, user: other_agent, inbox: inbox)
        conversation.update!(assignee: other_agent, team: other_team)
        create(:conversation_participant, conversation: conversation, user: agent)
      end

      it 'returns participant conversations even outside the user team or assigned to others' do
        result = described_class.new(account.conversations, agent, account).perform

        expect(result).to include(conversation)
      end
    end

    context 'when plan_hint_selective_filter is enabled' do
      let!(:other_inbox) { create(:inbox, account: account) }
      let!(:inaccessible_conversation) { create(:conversation, account: account, inbox: other_inbox) }

      it 'returns the same conversations as the default scoping for an agent' do
        default_result = described_class.new(account.conversations, agent, account).perform
        hinted_result = described_class.new(account.conversations, agent, account, plan_hint_selective_filter: true).perform

        expect(hinted_result.to_a).to match_array(default_result.to_a)
        expect(hinted_result).not_to include(inaccessible_conversation)
      end

      it 'keeps the planner hint in the generated query' do
        hinted_result = described_class.new(account.conversations, agent, account, plan_hint_selective_filter: true).perform

        expect(hinted_result.to_sql).to include('conversations.inbox_id + 0')
      end

      it 'does not change administrator scoping' do
        result = described_class.new(account.conversations, admin, account, plan_hint_selective_filter: true).perform

        expect(result.to_sql).not_to include('inbox_id + 0')
        expect(result).to include(inaccessible_conversation)
      end
    end
  end
end
