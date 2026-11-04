require 'rails_helper'

RSpec.describe SmartReceptionListener do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, timezone: 'UTC') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: nil, team: nil) }
  let(:message) { create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming, content: 'Oi') }
  let(:event) { Events::Base.new('message_created', Time.current, message: message) }

  before do
    account.enable_features!('saas_ai_smart_reception')
    create(:smart_reception_setting, account: account, inbox: inbox)
    Time.zone = 'UTC'
    travel_to '02.11.2026 10:00'.to_datetime
  end

  after do
    Time.zone = 'UTC'
  end

  it 'enqueues a response during business hours' do
    expect do
      described_class.instance.message_created(event)
    end.to have_enqueued_job(SmartReception::ResponseJob)
  end

  it 'stops Smart Reception when a human agent sends a message' do
    conversation.update!(smart_reception_active: true)
    agent = create(:user, account: account)
    outgoing = create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      message_type: :outgoing,
      sender: agent,
      content: 'Vou assumir o atendimento'
    )
    outgoing_event = Events::Base.new('message_created', Time.current, message: outgoing)

    described_class.instance.message_created(outgoing_event)

    expect(conversation.reload.smart_reception_active).to be(false)
    expect(conversation.custom_attributes[SmartReception::ConversationPolicy::HANDOFF_KEY]).to be(true)
  end

  it 'does not enqueue a response outside business hours' do
    inbox.update!(working_hours_enabled: true)
    inbox.working_hours.find_by(day_of_week: 1).update!(closed_all_day: true)

    expect do
      described_class.instance.message_created(event)
    end.not_to have_enqueued_job(SmartReception::ResponseJob)
  end
end
