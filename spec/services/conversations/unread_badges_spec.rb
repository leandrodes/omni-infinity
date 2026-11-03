require 'rails_helper'

RSpec.describe Conversations::UnreadBadges do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) do
    create(:conversation, account: account, inbox: inbox, contact: contact, assignee: user, status: :open)
  end

  before do
    create(:message, account: account, conversation: conversation, message_type: :incoming)
    conversation.update!(agent_last_seen_at: nil)
  end

  it 'counts open conversations assigned to the user' do
    counts = described_class.new(account: account, user: user).perform

    expect(counts[:open_mine_count]).to eq(1)
    expect(counts[:open_team_count]).to eq(1)
  end

  it 'does not restrict administrator open team counts to their teams' do
    account.update!(settings: account.settings.merge('show_conversations_only_from_user_teams' => true))

    counts = described_class.new(account: account, user: user).perform

    expect(counts[:open_team_count]).to eq(1)
  end

  it 'counts visible open conversations instead of unread conversations' do
    read_conversation = create(
      :conversation,
      account: account,
      inbox: inbox,
      contact: contact,
      assignee: user,
      status: :open,
      agent_last_seen_at: 1.hour.from_now
    )
    create(:message, account: account, conversation: read_conversation, message_type: :incoming, created_at: 1.hour.ago)

    counts = described_class.new(account: account, user: user).perform

    expect(counts[:open_mine_count]).to eq(2)
  end

  it 'counts participant conversations separately from conversations assigned to the user' do
    participant = create(:user, account: account, role: :agent)
    create(:inbox_member, inbox: inbox, user: participant)
    participant_conversation = create(
      :conversation,
      account: account,
      inbox: inbox,
      contact: contact,
      assignee: participant,
      status: :open
    )
    create(:conversation_participant, conversation: participant_conversation, user: participant)
    create(:message, account: account, conversation: participant_conversation, message_type: :incoming)
    participant_conversation.update!(agent_last_seen_at: nil)

    counts = described_class.new(account: account, user: participant).perform

    expect(counts[:participating_count]).to eq(0)

    participant_conversation.update!(assignee: nil)

    counts = described_class.new(account: account, user: participant).perform

    expect(counts[:participating_count]).to eq(1)
  end

  it 'keeps unattended badges after the conversation is viewed' do
    conversation.update!(agent_last_seen_at: 1.hour.from_now)

    counts = described_class.new(account: account, user: user).perform

    expect(counts[:unattended_count]).to eq(1)
    expect(counts[:unattended_mine_count]).to eq(1)
  end

  it 'counts unassigned conversations without bot assignments' do
    create(:conversation, account: account, inbox: inbox, contact: contact, status: :open)
    create(:conversation, account: account, inbox: inbox, contact: contact, status: :open,
                          ai_assignee: create(:agent_bot, account: account))

    counts = described_class.new(account: account, user: user).perform

    expect(counts[:unassigned_count]).to eq(1)
  end

  it 'shows all pending conversations to administrators even when assigned conversations are hidden' do
    agent = create(:user, account: account, role: :agent)
    create(:inbox_member, inbox: inbox, user: agent)
    create(:conversation, account: account, inbox: inbox, contact: contact, assignee: agent, status: :pending)
    account.update!(settings: account.settings.merge('hide_conversations_assigned_to_others' => true))

    counts = described_class.new(account: account, user: user).perform

    expect(counts[:pending_count]).to eq(1)
  end

  it 'separates chatbot pending from human pending conversations' do
    agent_bot = create(:agent_bot, account: account)
    bot_conversation = create(
      :conversation,
      account: account,
      inbox: inbox,
      contact: contact,
      status: :pending,
      ai_assignee: agent_bot
    )
    human_conversation = create(
      :conversation,
      account: account,
      inbox: inbox,
      contact: contact,
      status: :pending,
      assignee: user
    )
    create(:message, account: account, conversation: bot_conversation, message_type: :incoming)
    create(:message, account: account, conversation: human_conversation, message_type: :incoming)

    counts = described_class.new(account: account, user: user).perform

    expect(counts[:chatbot_count]).to eq(1)
    expect(counts[:pending_count]).to eq(1)
    expect(counts[:pending_mine_count]).to eq(1)
  end
end
