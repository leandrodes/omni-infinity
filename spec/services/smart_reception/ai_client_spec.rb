require 'rails_helper'

RSpec.describe SmartReception::AiClient do
  let(:setting) do
    build(
      :smart_reception_setting,
      provider: 'openai',
      model: 'gpt-4.1-mini',
      api_key: 'sk-test',
      temperature: 0.2,
      max_response_tokens: 100
    )
  end

  it 'sends the conversation to an OpenAI-compatible provider' do
    stub_request(:post, 'https://api.openai.com/v1/chat/completions')
      .to_return(
        status: 200,
        body: { choices: [{ message: { content: 'Olá!' } }] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = described_class.new(setting).perform(
      messages: [
        { role: 'system', content: 'Atenda bem.' },
        { role: 'user', content: 'Oi' }
      ]
    )

    expect(result).to eq('Olá!')
    expect(
      a_request(:post, 'https://api.openai.com/v1/chat/completions')
        .with do |request|
          body = JSON.parse(request.body)
          body['model'] == 'gpt-4.1-mini' &&
            body['messages'].last['content'] == 'Oi' &&
            body['max_tokens'] == 100
        end
    ).to have_been_made
  end

  it 'raises a readable error when the provider rejects the request' do
    stub_request(:post, 'https://api.openai.com/v1/chat/completions')
      .to_return(
        status: 401,
        body: { error: { message: 'Invalid API key' } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    expect do
      described_class.new(setting).perform(messages: [{ role: 'user', content: 'Oi' }])
    end.to raise_error(SmartReception::AiClient::Error, 'Invalid API key')
  end
end
