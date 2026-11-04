require 'rails_helper'

RSpec.describe AutoAssignment::BalancedSelector do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:selector) { described_class.new(inbox: inbox) }
  let(:agent1) { create(:user, account: account, role: :agent) }
  let(:agent2) { create(:user, account: account, role: :agent) }
  let(:member1) { create(:inbox_member, inbox: inbox, user: agent1) }
  let(:member2) { create(:inbox_member, inbox: inbox, user: agent2) }

  it 'selects the agent with fewer open and pending conversations' do
    create(:conversation, inbox: inbox, assignee: agent1, status: :open)
    create(:conversation, inbox: inbox, assignee: agent1, status: :pending)
    create(:conversation, inbox: inbox, assignee: agent2, status: :open)

    expect(selector.select_agent([member1, member2])).to eq(agent2)
  end

  it 'rotates between equally loaded agents by the oldest assignment' do
    create(:conversation, inbox: inbox, assignee: agent1, status: :open, created_at: 2.hours.ago)
    create(:conversation, inbox: inbox, assignee: agent2, status: :open, created_at: 1.hour.ago)

    expect(selector.select_agent([member1, member2])).to eq(agent1)
  end

  it 'keeps rotating after the previous conversation is resolved' do
    create(:conversation, inbox: inbox, assignee: agent1, status: :resolved, created_at: 2.hours.ago)
    create(:conversation, inbox: inbox, assignee: agent2, status: :resolved, created_at: 1.hour.ago)

    expect(selector.select_agent([member1, member2])).to eq(agent1)
  end
end
