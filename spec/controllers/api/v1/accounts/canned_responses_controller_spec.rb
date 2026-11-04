require 'rails_helper'

RSpec.describe 'Canned Responses API', type: :request do
  let(:account) { create(:account) }

  before do
    create(:canned_response, account: account, content: 'Hey {{ contact.name }}, Thanks for reaching out', short_code: 'name-short-code')
  end

  describe 'GET /api/v1/accounts/{account.id}/canned_responses' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/canned_responses"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      it 'returns all the canned responses' do
        get "/api/v1/accounts/#{account.id}/canned_responses",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body).to eq(account.canned_responses.as_json)
      end

      it 'returns all the canned responses the user searched for' do
        cr1 = account.canned_responses.first
        create(:canned_response, account: account, content: 'Great! Looking forward', short_code: 'short-code')
        cr2 = create(:canned_response, account: account, content: 'Thanks for reaching out', short_code: 'content-with-thanks')
        cr3 = create(:canned_response, account: account, content: 'Thanks for reaching out', short_code: 'Thanks')

        params = { search: 'thanks' }

        get "/api/v1/accounts/#{account.id}/canned_responses",
            params: params,
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body).to eq(
          [cr3, cr2, cr1].as_json
        )
      end

      it 'ignores null bytes in the search string' do
        matching_response = create(:canned_response, account: account, content: 'Unique response', short_code: 'unique')

        get "/api/v1/accounts/#{account.id}/canned_responses",
            params: { search: "uni\0que" },
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body).to eq([matching_response].as_json)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/canned_responses' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/canned_responses"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an administrator' do
      let(:administrator) { create(:user, account: account, role: :administrator) }
      let(:agent) { create(:user, account: account, role: :agent) }

      it 'creates a new canned response' do
        params = { short_code: 'short', content: 'content' }

        post "/api/v1/accounts/#{account.id}/canned_responses",
             params: params,
             headers: administrator.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(account.canned_responses.count).to eq(2)
        expect(response.parsed_body['message_type']).to eq('quick')
      end

      it 'creates a farewell canned response for selected inboxes' do
        inbox = create(:inbox, account: account)
        params = {
          short_code: 'bye',
          content: 'Goodbye',
          message_type: 'farewell',
          available_for_all_inboxes: false,
          inbox_ids: [inbox.id]
        }

        post "/api/v1/accounts/#{account.id}/canned_responses",
             params: params,
             headers: administrator.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['message_type']).to eq('farewell')
        expect(response.parsed_body['inbox_ids']).to contain_exactly(inbox.id)
      end

      it 'does not allow agents to create canned responses' do
        post "/api/v1/accounts/#{account.id}/canned_responses",
             params: { short_code: 'agent', content: 'content' },
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PUT /api/v1/accounts/{account.id}/canned_responses/:id' do
    let(:canned_response) { CannedResponse.last }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        put "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an administrator' do
      let(:administrator) { create(:user, account: account, role: :administrator) }
      let(:agent) { create(:user, account: account, role: :agent) }

      it 'updates an existing canned response' do
        params = { short_code: 'B' }

        put "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}",
            params: params,
            headers: administrator.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(canned_response.reload.short_code).to eq('B')
      end

      it 'clears selected inboxes when made available to all inboxes' do
        inbox = create(:inbox, account: account)
        canned_response.update!(available_for_all_inboxes: false)
        canned_response.inbox_ids = [inbox.id]

        put "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}",
            params: { available_for_all_inboxes: true },
            headers: administrator.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(canned_response.reload.inbox_ids).to be_empty
      end

      it 'does not allow agents to update canned responses' do
        put "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}",
            params: { short_code: 'B' },
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/canned_responses/:id' do
    let(:canned_response) { CannedResponse.last }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an administrator' do
      let(:administrator) { create(:user, account: account, role: :administrator) }
      let(:agent) { create(:user, account: account, role: :agent) }

      it 'destroys the canned response' do
        delete "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}",
               headers: administrator.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:success)
        expect(CannedResponse.count).to eq(0)
      end

      it 'does not allow agents to destroy canned responses' do
        delete "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}",
               headers: agent.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
