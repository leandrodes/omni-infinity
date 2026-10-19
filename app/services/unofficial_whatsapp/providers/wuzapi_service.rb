class UnofficialWhatsapp::Providers::WuzapiService < UnofficialWhatsapp::Providers::BaseService
  # `ReadReceipt` carries the delivery/read acknowledgements from whatsmeow,
  # which we map onto the outgoing message status (single/double gray/blue ticks).
  DEFAULT_EVENTS = 'Message,ReadReceipt,CallOffer,CallTerminate'.freeze

  def create_session(name:, webhook:, events: DEFAULT_EVENTS, proxy_url: nil)
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
    user_post('/webhook', { 'webhookURL' => url, 'events' => event_list(DEFAULT_EVENTS) })
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

  def apply_media_delivery
    remote_id = channel.provider_config['wuzapi_user_id']
    return unless remote_id.present?

    admin_put("/admin/users/#{remote_id}", { s3Config: { enabled: false, mediaDelivery: 'base64' } })
  rescue StandardError => e
    Rails.logger.warn("WuzAPI apply media delivery failed: #{e.class}: #{e.message}")
  end

  def connect(events: DEFAULT_EVENTS)
    apply_media_delivery
    # Persist the subscription even when the session is already connected:
    # /session/connect returns 409 in that case and would not update events.
    apply_webhook_events(events)
    response = user_post('/session/connect', { 'Subscribe' => event_list(events), 'Immediate' => true })
    response
  end

  def apply_webhook_events(events)
    webhook_url = channel.inbox&.callback_webhook_url
    return if webhook_url.blank?

    user_post('/webhook', { 'webhookURL' => webhook_url, 'events' => event_list(events), 'Active' => true })
  rescue StandardError => e
    Rails.logger.warn("WuzAPI apply webhook events failed: #{e.class}: #{e.message}")
  end

  def event_list(events)
    Array(events.split(',')).map(&:strip).compact_blank
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
    @endpoint ||= config_for('WUZAPI_ENDPOINT', nil).to_s.chomp('/')
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
    payload = { 'Phone' => phone_number, media_type => data_url(attachment), 'Id' => id }
    payload['Caption'] = message.outgoing_content if %w[image video document].include?(media_type)
    if media_type == 'audio'
      payload['MimeType'] = audio_mime_type(attachment)
      payload['PTT'] = true
    elsif media_type == 'document'
      payload['FileName'] = attachment.file.filename.to_s
      payload['MimeType'] = attachment.file.content_type
    end

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

  def audio_mime_type(attachment)
    content_type = attachment.file.content_type.to_s
    return 'audio/ogg; codecs=opus' if %w[audio/ogg audio/opus application/ogg application/x-ogg].include?(content_type)

    content_type.presence || 'audio/ogg; codecs=opus'
  end

  def process_response(response, message, id)
    parsed = response.parsed_response
    if response.success? && parsed['success'] != false
      # WuzAPI returns the actual whatsmeow message id in data.Id; receipts
      # (delivered/read) reference this id, so it must be our source_id.
      parsed.dig('data', 'Id').presence || id
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
