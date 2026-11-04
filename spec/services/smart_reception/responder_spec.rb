require 'rails_helper'

RSpec.describe SmartReception::Responder do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: nil, team: nil) }
  let(:setting) { create(:smart_reception_setting, account: account, inbox: inbox) }
  let!(:message) { create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming, content: 'humano') }

  describe 'keyword rules' do
    let(:team) { create(:team, account: account) }

    it 'transfers the conversation and stops without calling the AI' do
      create(:smart_reception_keyword_rule, account: account, setting: setting, team: team, keywords: 'humano', action: 'transfer')
      allow(SmartReception::AiClient).to receive(:new).and_raise('AI should not be called')

      result = described_class.new(setting: setting, conversation: conversation, message: message).perform

      expect(result).to eq(:rule_applied)
      expect(conversation.reload.team_id).to eq(team.id)
      expect(conversation.status).to eq('pending')
      expect(conversation.custom_attributes[SmartReception::ConversationPolicy::HANDOFF_KEY]).to be(true)
    end

    it 'resolves the conversation when the rule action is resolve' do
      create(:smart_reception_keyword_rule, account: account, setting: setting, team: nil, keywords: 'humano', action: 'resolve')
      allow(SmartReception::AiClient).to receive(:new).and_raise('AI should not be called')

      described_class.new(setting: setting, conversation: conversation, message: message).perform

      expect(conversation.reload).to be_resolved
    end
  end

  describe 'AI response' do
    it 'sends the generated response as an outgoing message' do
      ai_client = instance_double(SmartReception::AiClient, perform: 'Olá! Como posso ajudar?')
      allow(SmartReception::AiClient).to receive(:new).and_return(ai_client)

      result = described_class.new(setting: setting, conversation: conversation, message: message).perform

      expect(result).to eq(:responded)
      expect(conversation.reload.messages.outgoing.last.content).to eq('Olá! Como posso ajudar?')
      expect(conversation.messages.outgoing.last.content_attributes['smart_reception']).to be(true)
      expect(conversation.smart_reception_active).to be(true)
    end
  end
end
