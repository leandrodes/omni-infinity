class UnofficialWhatsapp::Providers::WuzapiService < UnofficialWhatsapp::Providers::BaseService
  def create_session(name:, webhook:, events: 'Message', proxy_url: nil)
    remote_token = SecureRandom.hex(24)
    payload = { name: name, token: remote_token, webhook: webhook, events: events }
    payload[:s3Config] = { enabled: false, mediaDelivery: 'base64' }
    if proxy_url.present?
      payload[:proxyConfig] = { enabled: true, proxyURL: proxy_url, webhookUseProxy: true }
    end
    response = admin_post('/admin/users', payload)
    raise WuzapiError, "WuzAPI: failed to create user (#{response.code}) #{response.body}" unless response.success?

    remote_id = response.parsed_response.dig('data', 'id') || response.parsed_response['id']
    { token: remote_token, id: remote_id }
  end

  def delete_session(remote_id)
    admin_delete("/admin/users/#{remote_id}")
  end


  def disconnect
    user_post('/session/disconnect', {})
  end

  def qrcode
    user_get('/session/qr')
  end

  def status
    user_get('/session/status')
  end

  def set_webhook(url)
    user_post('/webhook', { 'webhookURL' => url })
  end

  def logout
    user_post('/session/logout', {})
  end

  def reject_call(call_from:, call_id:)
    return if call_from.blank? || call_id.blank?

    user_post('/call/reject', { 'CallFrom' => call_from, 'CallID' => call_id })
  rescue StandardError => e
    Rails.logger.warn("WuzAPI reject call failed: #{e.class}: #{e.message}")
  end

  def apply_proxy(enabled, proxy_url)
    remote_id = channel.provider_config['wuzapi_user_id']
    return if remote_id.blank?

    proxy_payload = {
      enabled: enabled,
      proxyURL: enabled ? proxy_url : '',
      webhookUseProxy: true
    }
    admin_put("/admin/users/#{remote_id}", { proxyConfig: proxy_payload })
  rescue StandardError => e
    Rails.logger.warn("WuzAPI apply proxy failed: #{e.class}: #{e.message}")
  end

  def connect(events: 'Message,CallOffer,CallTerminate')
    response = user_post('/session/connect', { 'Subscribe' => Array(events.split(',')).map(&:strip), 'Immediate' => true })
    response
  end

  def validate_provider_config?
    endpoint.present? && admin_token.present?
  end

  def send_message(phone_number, message)
    @message = message
    if message.attachments.present?
      send_attachment_message(phone_number, message)
    else
      send_text_message(phone_number, message)
    end
  end

  def endpoint
    @endpoint ||= config_for('WUZAPI_ENDPOINT', 'http://wuzapi:8080').to_s.chomp('/')
  end

  def admin_token
    @admin_token ||= config_for('WUZAPI_ADMIN_TOKEN', nil).to_s
  end

  private

  # Prefer the value set in the Super-Admin screen (InstallationConfig/GlobalConfig)
  # and fall back to the environment variable. A plain GlobalConfigService.load
  # would not fall back correctly here, because ConfigLoader pre-creates a blank
  # record for WUZAPI_ADMIN_TOKEN (no default in installation_config.yml), which
  # then shadows the ENV value.
  def config_for(key, default = nil)
    GlobalConfig.get(key)[key].presence || ENV.fetch(key, default)
  end

  def send_text_message(phone_number, message)
    id = outbound_message_id(message)
    response = user_post('/chat/send/text', { 'Phone' => phone_number, 'Body' => message.outgoing_content, 'Id' => id })
    process_response(response, message, id)
  end

  def send_attachment_message(phone_number, message)
    attachment = message.attachments.first
    id = outbound_message_id(message)
    media_type = wuzapi_media_type(attachment.file_type)
    payload = { 'Phone' => phone_number, media_type => data_url(attachment) }
    payload['Caption'] = message.outgoing_content if %w[image video document].include?(media_type)
    payload['FileName'] = attachment.file.filename.to_s if media_type == 'document'

    response = user_post("/chat/send/#{media_type}", payload)
    process_response(response, message, id)
  end

  def wuzapi_media_type(file_type)
    return file_type if %w[image video audio document sticker].include?(file_type)

    'document'
  end

  def data_url(attachment)
    bytes = attachment.file.download
    content_type = attachment.file.content_type
    "data:#{content_type};base64,#{Base64.strict_encode64(bytes)}"
  end

  def process_response(response, message, id)
    parsed = response.parsed_response
    if response.success? && parsed['success'] != false
      id
    else
      handle_error(response, message)
      nil
    end
  end

  def handle_error(response, message)
    Rails.logger.error "[UNOFFICIAL_WHATSAPP] #{response.body}"
    return if message.blank?

    message.external_error = error_message(response)
    message.status = :failed
    message.save!
  end

  def error_message(response)
    parsed = response.parsed_response rescue {}
    parsed['message'] || parsed['error'] || response.body.to_s.first(255)
  end

  def outbound_message_id(message)
    message.source_id.presence || "OMNI-#{message.id}-#{SecureRandom.hex(6).upcase}"
  end

  def api_headers
    { 'Content-Type' => 'application/json' }
  end

  def user_headers
    api_headers.merge('Token' => channel.instance_token.to_s)
  end

  def admin_headers
    api_headers.merge('Authorization' => admin_token)
  end

  def user_get(path)
    HTTParty.get("#{endpoint}#{path}", headers: user_headers)
  end

  def user_post(path, body)
    HTTParty.post("#{endpoint}#{path}", headers: user_headers, body: body.to_json)
  end

  def admin_post(path, body)
    HTTParty.post("#{endpoint}#{path}", headers: admin_headers, body: body.to_json)
  end

  def admin_delete(path)
    HTTParty.delete("#{endpoint}#{path}", headers: admin_headers)
  end

  def admin_put(path, body)
    HTTParty.put("#{endpoint}#{path}", headers: admin_headers, body: body.to_json)
  end

  class WuzapiError < StandardError; end
end
