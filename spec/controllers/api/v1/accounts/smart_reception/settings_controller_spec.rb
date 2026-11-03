require 'rails_helper'

RSpec.describe '/api/v1/accounts/{account.id}/inboxes/:inbox_id/smart_reception_setting', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }
  let(:url) { "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/smart_reception_setting" }

  before do
    account.enable_features!('saas_ai_smart_reception')
  end

  describe 'GET smart_reception_setting' do
    it 'returns the default settings and provider options' do
      get url, headers: admin.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.dig('payload', 'provider')).to eq('openai')
      expect(response.parsed_body.dig('payload', 'primary_prompt')).to be_present
      expect(response.parsed_body.dig('options', 'providers').map { |provider| provider['value'] }).to include('openai', 'gemini')
    end
  end

  describe 'PATCH smart_reception_setting' do
    it 'saves the configuration and keyword rules' do
      params = {
        smart_reception_setting: {
          enabled: true,
          name: 'Recepção Infinity',
          provider: 'openai',
          model: 'gpt-4.1-mini',
          api_key: 'sk-test',
          temperature: 0.2,
          max_response_tokens: 500,
          max_history_messages: 20,
          min_wait_seconds: 5,
          max_wait_seconds: 20,
          primary_prompt: 'Atenda com educação.',
          secondary_prompt: 'Seja objetiva.',
          team_id: team.id
        },
        keyword_rules: [
          { keywords: 'humano, atendente', action: 'transfer', team_id: team.id, enabled: true }
        ]
      }

      patch url, params: params, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      setting = inbox.reload.smart_reception_setting
      expect(setting).to be_enabled
      expect(setting.name).to eq('Recepção Infinity')
      expect(setting.keyword_rules.count).to eq(1)
      expect(response.parsed_body.dig('payload', 'api_key_present')).to be(true)
      expect(response.parsed_body.dig('payload', 'api_key')).to be_nil
    end

    it 'keeps the current API key when the field is left blank' do
      create(:smart_reception_setting, account: account, inbox: inbox, api_key: 'sk-existing')

      patch url,
            params: { smart_reception_setting: { enabled: true, provider: 'openai', model: 'gpt-4.1-mini' } },
            headers: admin.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(inbox.reload.smart_reception_setting.api_key).to eq('sk-existing')
      expect(response.parsed_body.dig('payload', 'api_key_present')).to be(true)
    end

    it 'does not enable Smart Reception while a chatbot is connected' do
      create(:agent_bot_inbox, inbox: inbox)

      patch url,
            params: { smart_reception_setting: { enabled: true, api_key: 'sk-test' } },
            headers: admin.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to include('chatbot')
      expect(inbox.reload.smart_reception_setting&.enabled).not_to be(true)
    end
  end

  describe 'when the feature is disabled for the account' do
    before do
      account.disable_features!('saas_ai_smart_reception')
    end

    it 'returns not found' do
      get url, headers: admin.create_new_auth_token

      expect(response).to have_http_status(:not_found)
    end
  end
end
