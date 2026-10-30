require 'rails_helper'

RSpec.describe 'Conversation visibility API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, assignee: agent) }

  before do
    create(:inbox_member, user: agent, inbox: conversation.inbox)
    create(:inbox_member, user: other_agent, inbox: conversation.inbox)
  end

  describe 'PATCH /api/v1/accounts/{account.id}/conversations/{conversation.id}/visibility' do
    it 'makes the current assignee the private owner' do
      patch "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/visibility",
            params: { restricted: true },
            headers: agent.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      conversation.reload
      expect(conversation).to be_restricted
      expect(conversation.private_owner_id).to eq(agent.id)
      expect(conversation.assignee_id).to eq(agent.id)
    end

    it 'does not allow another agent to change visibility' do
      patch "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/visibility",
            params: { restricted: true },
            headers: other_agent.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:forbidden)
      expect(conversation.reload).to be_shared
    end

    it 'allows the owner to make the conversation public again' do
      conversation.update!(visibility: :restricted, private_owner_id: agent.id)

      patch "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/visibility",
            params: { restricted: false },
            headers: agent.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(conversation.reload).to be_shared
      expect(conversation.private_owner_id).to be_nil
    end
  end
end
