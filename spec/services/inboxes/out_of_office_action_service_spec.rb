require 'rails_helper'

RSpec.describe Inboxes::OutOfOfficeActionService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, timezone: 'UTC', working_hours_enabled: true) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, status: :open) }

  before do
    Time.zone = 'UTC'
    travel_to '02.11.2026 18:00'.to_datetime
  end

  after do
    Time.zone = 'UTC'
  end

  it 'resolves out-of-hours conversations when configured' do
    inbox.update!(out_of_office_action: 'resolve')

    described_class.new(conversation: conversation).perform

    expect(conversation.reload).to be_resolved
  end

  it 'moves out-of-hours conversations to the configured pending team' do
    team = create(:team, account: account)
    inbox.update!(out_of_office_action: 'pending_team', out_of_office_team_id: team.id)

    described_class.new(conversation: conversation).perform

    expect(conversation.reload).to be_pending
    expect(conversation.team_id).to eq(team.id)
    expect(conversation.assignee_id).to be_nil
  end
end
