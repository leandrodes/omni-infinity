require 'rails_helper'

RSpec.describe '/api/v1/accounts/{account.id}/unofficial_campaigns', type: :request do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:payload) do
    {
      title: 'Campanha de teste',
      sender_inbox_ids: [inbox.id],
      start_mode: 'immediate',
      min_contact_interval_seconds: 10,
      max_contact_interval_seconds: 20,
      pause_enabled: false,
      allowed_days: [1, 2, 3, 4, 5],
      allowed_start_minute: 480,
      allowed_end_minute: 1080,
      post_action: 'pending_team',
      post_team_id: team.id,
      contact_ids: [contact.id],
      messages: [
        {
          wait_min_seconds: 3,
          wait_max_seconds: 8,
          variants: [
            { content: 'Versão 1' },
            { content: 'Versão 2' },
            { content: 'Versão 3' }
          ]
        }
      ]
    }
  end
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, account: account, name: 'Maria', phone_number: '+5511988887777') }
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

  before do
    account.enable_features!('campaigns')
  end

  it 'creates a campaign and schedules it' do
    post "/api/v1/accounts/#{account.id}/unofficial_campaigns",
         params: { campaign: payload.to_json },
         headers: admin.create_new_auth_token

    expect(response).to have_http_status(:created)
    expect(UnofficialCampaigns::ContactJob).to have_been_enqueued
    campaign = UnofficialCampaign.last
    expect(campaign.title).to eq('Campanha de teste')
    expect(campaign.contacts.count).to eq(1)
    expect(campaign.messages.first.variants.count).to eq(3)
  end

  it 'imports contacts from a CSV file' do
    file = fixture_file_upload('spec/fixtures/files/unofficial_campaign_contacts.csv', 'text/csv')
    payload[:contact_ids] = []

    post "/api/v1/accounts/#{account.id}/unofficial_campaigns",
         params: { campaign: payload.to_json, contacts_file: file },
         headers: admin.create_new_auth_token

    expect(response).to have_http_status(:created)
    campaign = UnofficialCampaign.last
    expect(campaign.contacts.count).to eq(2)
    expect(campaign.contacts.pluck(:name)).to contain_exactly('João Exemplo', 'Maria Exemplo')
    expect(campaign.contacts.pluck(:source).uniq).to eq(['csv'])
  end

  it 'does not allow a campaign without three variants' do
    payload[:messages][0][:variants] = [{ content: 'Só uma' }]

    post "/api/v1/accounts/#{account.id}/unofficial_campaigns",
         params: { campaign: payload.to_json },
         headers: admin.create_new_auth_token

    expect(response).to have_http_status(:unprocessable_entity)
    expect(UnofficialCampaign.count).to eq(0)
  end
end
