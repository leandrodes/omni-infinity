require 'rails_helper'

RSpec.describe AutoAssignment::PrioritySelector do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:selector) { described_class.new(inbox: inbox) }
  let(:agent1) { create(:user, account: account, role: :agent) }
  let(:agent2) { create(:user, account: account, role: :agent) }
  let!(:member1) { create(:inbox_member, inbox: inbox, user: agent1, priority_level: 2) }
  let!(:member2) { create(:inbox_member, inbox: inbox, user: agent2, priority_level: 1) }

  it 'selects the agent with the lowest priority level' do
    expect(selector.select_agent([member1, member2])).to eq(agent2)
  end

  it 'uses the least loaded agent inside the same level' do
    member2.update!(priority_level: 2)
    create(:conversation, inbox: inbox, assignee: agent1, status: :open)

    expect(selector.select_agent([member1, member2])).to eq(agent2)
  end
end
