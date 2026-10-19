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
    interactive = interactive_payload(message)
    if interactive.present?
      send_interactive_message(phone_number, message, interactive)
    elsif message.attachments.present?
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
      seconds = audio_duration_seconds(attachment)
      payload['Seconds'] = seconds if seconds&.positive?
    elsif media_type == 'document'
      payload['FileName'] = attachment.file.filename.to_s
      payload['MimeType'] = attachment.file.content_type
    end

    response = user_post("/chat/send/#{media_type}", payload)
    process_response(response, message, id)
  end

  # Mensagens interativas (botões/listas) do WuzAPI. Esperamos que o gerador da
  # mensagem (ex.: flow builder) popule `content_attributes['interactive']`:
  #   { "type": "buttons", "body": "...", "buttons": [{ "title": "...", "id": "..." }] }
  #   { "type": "list", "body": "...", "button": "Menu",
  #     "sections": [{ "title": "...", "rows": [{ "title": "...", "description": "...", "id": "..." }] }] }
  def interactive_payload(message)
    attrs = message.content_attributes || {}
    data = attrs['interactive'] || attrs[:interactive]
    return nil unless data.is_a?(Hash) || data.is_a?(ActiveSupport::HashWithIndifferentAccess)
    return nil if data['buttons'].blank? && data['sections'].blank?

    data
  end

  def send_interactive_message(phone_number, message, data)
    type = (data['type'] || 'buttons').to_s
    if type == 'list'
      send_list_message(phone_number, message, data)
    else
      send_buttons_message(phone_number, message, data)
    end
  end

  def send_buttons_message(phone_number, message, data)
    id = outbound_message_id(message)
    buttons = Array(data['buttons']).filter_map do |button|
      title = button['title'].to_s.strip
      next if title.blank?

      { 'type' => (button['type'] || 'reply').to_s, 'title' => title, 'id' => (button['id'] || title).to_s }
    end
    return send_text_message(phone_number, message) if buttons.empty?

    payload = {
      'Phone' => phone_number,
      'Body' => (data['body'] || message.outgoing_content).to_s,
      'Buttons' => buttons,
      'Id' => id
    }
    payload['Footer'] = data['footer'].to_s if data['footer'].present?
    response = user_post('/chat/send/buttons', payload)
    process_response(response, message, id)
  end

  def send_list_message(phone_number, message, data)
    id = outbound_message_id(message)
    sections = Array(data['sections']).filter_map do |section|
      rows = Array(section['rows']).filter_map do |row|
        title = row['title'].to_s.strip
        next if title.blank?

        { 'title' => title, 'desc' => row['description'].to_s, 'RowId' => (row['id'] || title).to_s }
      end
      next if rows.empty?

      { 'title' => section['title'].to_s, 'rows' => rows }
    end
    return send_text_message(phone_number, message) if sections.empty?

    payload = {
      'Phone' => phone_number,
      'ButtonText' => (data['button'] || 'Selecionar').to_s,
      'Desc' => (data['body'] || message.outgoing_content).to_s,
      'Sections' => sections,
      'Id' => id
    }
    payload['TopText'] = data['header'].to_s if data['header'].present?
    payload['FooterText'] = data['footer'].to_s if data['footer'].present?
    response = user_post('/chat/send/list', payload)
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

  def audio_duration_seconds(attachment)
    content_type = attachment.file.content_type.to_s
    return unless %w[audio/ogg audio/opus application/ogg application/x-ogg].include?(content_type)

    ogg_duration_seconds(attachment.file.download)
  end

  # The last OGG page granule position holds the total number of 48 kHz samples,
  # which is how WhatsApp derives the voice note duration shown to recipients.
  def ogg_duration_seconds(bytes)
    io = StringIO.new(bytes)
    last_granule = 0
    loop do
      header = io.read(27)
      break if header.nil? || header.bytesize < 27 || !header.start_with?('OggS')

      granule = header.byteslice(6, 8).unpack1('q<')
      segment_count = header.getbyte(26)
      segment_table = io.read(segment_count).to_s.bytes
      io.seek(segment_table.sum, IO::SEEK_CUR)
      last_granule = granule if granule.positive?
    end
    return if last_granule <= 0

    (last_granule / 48_000.0).round
  rescue StandardError
    nil
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
