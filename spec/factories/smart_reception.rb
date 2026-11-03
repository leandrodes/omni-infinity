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
