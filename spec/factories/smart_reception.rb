FactoryBot.define do
  factory :smart_reception_setting, class: 'SmartReception::Setting' do
    account
    inbox
    name { 'Recepção Inteligente' }
    provider { 'openai' }
    model { 'gpt-4.1-mini' }
    api_key { 'sk-test' }
    enabled { true }
  end

  factory :smart_reception_keyword_rule, class: 'SmartReception::KeywordRule' do
    account
    setting factory: :smart_reception_setting
    keywords { 'humano, atendente' }
    action { 'transfer' }
    team
  end
end


FactoryBot.define do
  factory :unofficial_campaign do
    account
    title { 'Campanha' }
    sender_inbox_ids { [] }
    start_mode { 'immediate' }
    min_contact_interval_seconds { 10 }
    max_contact_interval_seconds { 20 }
    allowed_days { (0..6).to_a }
    allowed_start_minute { 0 }
    allowed_end_minute { 1439 }
    post_action { 'resolve' }
  end

  factory :unofficial_campaign_message do
    campaign factory: :unofficial_campaign
    sequence(:position)
    wait_min_seconds { 3 }
    wait_max_seconds { 8 }
  end

  factory :unofficial_campaign_variant do
    message factory: :unofficial_campaign_message
    sequence(:position)
    content { 'Mensagem' }
  end

  factory :unofficial_campaign_contact do
    campaign factory: :unofficial_campaign
    contact
    phone_number { contact.phone_number }
  end
end
