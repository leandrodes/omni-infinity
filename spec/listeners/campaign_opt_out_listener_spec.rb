require 'rails_helper'

RSpec.describe CampaignOptOutListener do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, phone_number: '+5511988887777') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:message) { create(:message, account: account, conversation: conversation, inbox: inbox, message_type: :incoming, content: 'PARAR') }
  let(:event) { Events::Base.new('message_created', Time.current, message: message) }

  it 'marks the contact as campaign opt-out' do
    described_class.instance.message_created(event)

    expect(contact.reload.campaign_opt_out).to be(true)
  end
end
