require 'net/http'
require 'json'
require 'cgi'

# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
class SmartReception::AiClient
  class Error < StandardError; end

  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 90

  attr_reader :setting

  def initialize(setting)
    @setting = setting
  end

  def perform(messages:)
    config = SmartReception::ProviderCatalog.fetch(setting.provider)
    raise Error, 'Provedor de IA indisponível.' if config.blank? || config[:coming_soon]
    raise Error, 'Informe a chave de API do provedor.' if setting.api_key.blank?

    config[:adapter] == 'gemini' ? gemini_request(config, messages) : openai_request(config, messages)
  end

  private

  def openai_request(config, messages)
    uri = URI.join("#{config[:base_url].chomp('/')}/", 'chat/completions')
    body = {
      model: setting.model,
      messages: messages,
      temperature: setting.temperature.to_f
    }
    body[token_parameter] = setting.max_response_tokens

    response = post_json(uri, body, 'Authorization' => "Bearer #{setting.api_key}")
    content = response.dig('choices', 0, 'message', 'content')
    raise Error, response.dig('error', 'message') || 'Resposta vazia do provedor de IA.' if content.blank?

    content.to_s.strip
  end

  def gemini_request(config, messages)
    uri = URI(
      "#{config[:base_url]}/models/#{CGI.escape(setting.model)}:generateContent?key=#{CGI.escape(setting.api_key)}"
    )
    system_message = messages.find { |message| message[:role] == 'system' }
    conversation = messages.reject { |message| message[:role] == 'system' }

    body = {
      systemInstruction: system_message.present? ? { parts: [{ text: system_message[:content] }] } : nil,
      contents: conversation.map do |message|
        {
          role: message[:role].to_s == 'assistant' ? 'model' : 'user',
          parts: [{ text: message[:content].to_s }]
        }
      end,
      generationConfig: {
        temperature: setting.temperature.to_f,
        maxOutputTokens: setting.max_response_tokens
      }
    }.compact

    response = post_json(uri, body)
    content = Array(response.dig('candidates', 0, 'content', 'parts')).filter_map { |part| part['text'] }.join("\n")
    raise Error, response.dig('error', 'message') || 'Resposta vazia do provedor de IA.' if content.blank?

    content.strip
  end

  def post_json(uri, body, headers = {})
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    headers.each { |key, value| request[key] = value }
    request.body = body.to_json

    response = Net::HTTP.start(
      uri.host,
      uri.port,
      use_ssl: uri.scheme == 'https',
      open_timeout: OPEN_TIMEOUT,
      read_timeout: READ_TIMEOUT
    ) { |http| http.request(request) }

    parsed = JSON.parse(response.body.presence || '{}')
    return parsed if response.is_a?(Net::HTTPSuccess)

    raise Error, parsed.dig('error', 'message') || parsed['message'] || "Erro #{response.code} do provedor de IA."
  rescue JSON::ParserError
    raise Error, "Resposta inválida do provedor de IA (#{response.code})."
  rescue Timeout::Error, SocketError, SystemCallError => e
    raise Error, "Falha de conexão com o provedor de IA: #{e.message}"
  end

  def token_parameter
    setting.model.to_s.match?(/\A(gpt-5|o1|o3|o4)/) ? 'max_completion_tokens' : 'max_tokens'
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
