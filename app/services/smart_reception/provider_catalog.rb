class SmartReception::ProviderCatalog
  PROVIDERS = {
    'openai' => {
      label: 'OpenAI',
      adapter: 'openai',
      base_url: 'https://api.openai.com/v1',
      models: %w[gpt-5.5 gpt-5.4 gpt-5.4-mini gpt-5.2 gpt-5.1 gpt-5 gpt-4.1-mini]
    },
    'groq' => {
      label: 'Groq',
      adapter: 'openai',
      base_url: 'https://api.groq.com/openai/v1',
      models: %w[openai/gpt-oss-120b openai/gpt-oss-20b]
    },
    'gemini' => {
      label: 'Gemini',
      adapter: 'gemini',
      base_url: 'https://generativelanguage.googleapis.com/v1beta',
      models: %w[gemini-3.5-flash gemini-3-flash-preview gemini-2.5-flash gemini-flash-latest]
    },
    'perplexity' => {
      label: 'Perplexity',
      adapter: 'openai',
      base_url: 'https://api.perplexity.ai',
      models: %w[sonar sonar-pro]
    },
    'deepseek' => {
      label: 'DeepSeek',
      adapter: 'openai',
      base_url: 'https://api.deepseek.com/v1',
      models: %w[deepseek-chat deepseek-reasoner]
    },
    'infinity' => {
      label: 'Infinity',
      adapter: 'openai',
      base_url: nil,
      coming_soon: true,
      models: []
    }
  }.freeze

  class << self
    def providers
      PROVIDERS.map do |key, config|
        {
          value: key,
          label: config[:label],
          coming_soon: config[:coming_soon] == true,
          models: config[:models].map { |model| { value: model, label: model } }
        }
      end
    end

    def fetch(provider)
      PROVIDERS[provider.to_s]
    end

    def supported?(provider, model = nil)
      config = fetch(provider)
      return false unless config && config[:coming_soon] != true

      model.blank? || config[:models].include?(model.to_s)
    end

    def default_model(provider)
      fetch(provider)&.dig(:models)&.first
    end
  end
end
