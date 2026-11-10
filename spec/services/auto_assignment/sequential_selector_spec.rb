require 'rails_helper'

RSpec.describe AutoAssignment::SequentialSelector do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:selector) { described_class.new(inbox: inbox) }
  let(:agent1) { create(:user, account: account, role: :agent) }
  let(:agent2) { create(:user, account: account, role: :agent) }
  let!(:member1) { create(:inbox_member, inbox: inbox, user: agent1, priority_level: 1) }
  let!(:member2) { create(:inbox_member, inbox: inbox, user: agent2, priority_level: 2) }

  it 'selects the lowest level when it is available' do
    expect(selector.select_agent([member1, member2])).to eq(agent1)
  end

  it 'moves to the next level when the lower level is busy' do
    create(:conversation, inbox: inbox, assignee: agent1, status: :open)

    expect(selector.select_agent([member1, member2])).to eq(agent2)
  end
end
