require 'rails_helper'

RSpec.describe UnofficialCampaigns::ContactJob do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account, phone_number: '+5511977776666', name: 'Cliente') }
  let(:channel) do
    account.enable_features!(:saas_channel_evolution)
    provider = instance_double(UnofficialWhatsapp::Providers::EvolutionService, validate_provider_config?: true)
    allow(UnofficialWhatsapp::Providers::EvolutionService).to receive(:new).and_return(provider)
    Channel::UnofficialWhatsapp.create!(
      account: account,
      provider: 'evolution',
      phone_number: '5511999999999',
      connection_status: 'connected'
    )
  end
  let(:inbox) { create(:inbox, account: account, channel: channel) }
  let(:team) { create(:team, account: account) }
  let(:campaign) do
    create(
      :unofficial_campaign,
      account: account,
      sender_inbox_ids: [inbox.id],
      allowed_days: (0..6).to_a,
      allowed_start_minute: 0,
      allowed_end_minute: 1439,
      post_action: 'pending_team',
      post_team_id: team.id,
      status: :running
    )
  end
  let(:message) { create(:unofficial_campaign_message, campaign: campaign, position: 0) }
  let!(:campaign_contact) do
    create(:unofficial_campaign_contact, campaign: campaign, contact: contact, phone_number: contact.phone_number)
  end

  before do
    create(:unofficial_campaign_variant, message: message, position: 0, content: 'Mensagem de campanha')
  end

  it 'sends the variant and finishes the contact' do
    described_class.perform_now(campaign.id, campaign_contact.id)

    expect(campaign_contact.reload).to be_sent
    conversation = contact.conversations.where(inbox: inbox).last
    expect(conversation.messages.outgoing.last.content).to eq('Mensagem de campanha')
    expect(conversation.reload).to be_pending
    expect(conversation.team_id).to eq(team.id)
  end
end
