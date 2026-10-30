require 'rails_helper'

RSpec.describe 'Pinned messages API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, assignee: agent) }
  let!(:message) { create(:message, conversation: conversation, account: account, message_type: :incoming) }

  before do
    create(:inbox_member, user: agent, inbox: conversation.inbox)
  end

  it 'pins, lists and unpins a message' do
    post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/messages/#{message.id}/pin",
         headers: agent.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:success)
    expect(message.reload.pinned_at).to be_present
    expect(message.pinned_by_id).to eq(agent.id)

    get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/messages/pinned",
        headers: agent.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['payload'].pluck('id')).to include(message.id)

    delete "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/messages/#{message.id}/unpin",
           headers: agent.create_new_auth_token,
           as: :json

    expect(response).to have_http_status(:success)
    expect(message.reload.pinned_at).to be_nil
  end
end
