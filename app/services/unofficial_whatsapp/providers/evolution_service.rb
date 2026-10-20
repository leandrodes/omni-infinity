class UnofficialWhatsapp::Providers::EvolutionService < UnofficialWhatsapp::Providers::BaseService
  DEFAULT_EVENTS = %w[
    MESSAGES_UPSERT
    MESSAGES_UPDATE
    SEND_MESSAGE
    CONNECTION_UPDATE
    QRCODE_UPDATED
  ].freeze

  def remote_id_key
    'evolution_instance'
  end

  def provisioned?
    instance_name.present?
  end

  def create_session(name:, webhook:, events: DEFAULT_EVENTS, proxy_url: nil)
    existing = channel.provider_config['evolution_instance']
    return { token: channel.instance_token, id: existing } if existing.present?

    payload = {
      instanceName: name.to_s.parameterize(separator: '-').presence || "omni-#{channel.id}",
      qrcode: true,
      integration: 'WHATSAPP-BAILEYS',
      webhook: {
        url: webhook,
        byEvents: false,
        base64: true,
        events: Array(events).map(&:to_s)
      }
    }
    response = admin_post('/instance/create', payload)
    unless response.success? || already_exists?(response)
      raise EvolutionError, "Evolution API: failed to create instance (#{response.code}) #{response.body}"
    end

    data = unwrap(response.parsed_response)
    instance = data['instance'].is_a?(Hash) ? data['instance'] : {}
    created_name = instance['instanceName'] || payload[:instanceName]
    token = data['hash'] || data['token'] || instance['token'] || instance['apikey']
    { token: token.presence || channel.instance_token, id: created_name }
  end

  def connect(events: DEFAULT_EVENTS)
    apply_webhook(events)
    instance_get("/instance/connect/#{instance_name}")
  end

  # A paired instance can get stuck in a reconnect/conflict loop created by
  # overlapping sockets. Restarting the remote instance closes the stale
  # socket before opening a new one; fall back to connect when it is not open.
  def reconnect(events: DEFAULT_EVENTS)
    apply_webhook(events)

    current = status
    if current.success? && parse_status(current)[:logged_in]
      restarted = instance_post("/instance/restart/#{instance_name}", {})
      return restarted if restarted.success?
    end

    instance_get("/instance/connect/#{instance_name}")
  end

  def qrcode
    instance_get("/instance/connect/#{instance_name}")
  end

  def qrcode_from(response)
    data = unwrap(response.parsed_response)
    qrcode = data['qrcode'].is_a?(Hash) ? data['qrcode'] : {}
    raw = data['base64'] || qrcode['base64'] || data['code'] || qrcode['code'] || data['pairingCode']
    return if raw.blank?

    raw = raw.to_s
    raw.start_with?('data:') ? raw : "data:image/png;base64,#{raw}"
  end

  def status
    instance_get("/instance/connectionState/#{instance_name}")
  end

  def parse_status(response)
    data = unwrap(response.parsed_response)
    instance = data['instance'].is_a?(Hash) ? data['instance'] : {}
    state = (instance['state'] || data['state'] || instance['status'] || data['status']).to_s.downcase
    {
      connected: %w[open connecting].include?(state),
      logged_in: state == 'open'
    }
  end

  def set_webhook(url)
    instance_post("/webhook/set/#{instance_name}", webhook_payload(url))
  end

  def send_message(phone_number, message)
    @message = message
    number = normalize_number(phone_number)
    interactive = interactive_payload(message)
    if interactive.present?
      send_interactive_message(number, message, interactive)
    elsif message.attachments.present?
      send_attachment_message(number, message)
    else
      send_text_message(number, message)
    end
  end

  def send_text_message(number, message, text = nil)
    id = outbound_message_id(message)
    body = (text || message.outgoing_content).to_s
    response = instance_post("/message/sendText/#{instance_name}", { number: number, text: body })
    process_response(response, message, id)
  end

  def logout
    instance_delete("/instance/logout/#{instance_name}")
  end

  alias disconnect logout

  def delete_session(_remote_id)
    instance_delete("/instance/delete/#{instance_name}")
  end

  def reject_call(call_from:, call_id:)
    nil
  end

  def apply_proxy(_enabled, _proxy_url)
    nil
  end

  def validate_provider_config?
    endpoint.present? && api_key.present?
  end

  def fetch_media_base64(message_key)
    response = instance_post(
      "/chat/getBase64FromMediaMessage/#{instance_name}",
      { message: { key: message_key }, convertToMp4: false }
    )
    return unless response.success?

    data = unwrap(response.parsed_response)
    data['base64'] || data.dig('data', 'base64')
  rescue StandardError => e
    Rails.logger.warn("Evolution media download failed: #{e.class}: #{e.message}")
    nil
  end

  def endpoint
    @endpoint ||= config_for('EVOLUTION_ENDPOINT').to_s.chomp('/')
  end

  def api_key
    @api_key ||= config_for('EVOLUTION_API_KEY').to_s
  end

  def instance_name
    @instance_name ||= channel.provider_config['evolution_instance'].to_s
  end

  private

  def config_for(key)
    GlobalConfig.get(key)[key].presence || ENV.fetch(key, nil)
  end

  def already_exists?(response)
    response.code.to_i == 409 || response.body.to_s.match?(/already|exists/i)
  end

  def unwrap(parsed)
    return {} unless parsed.is_a?(Hash)

    if parsed['response'].is_a?(Hash)
      parsed['response']
    elsif parsed['response'].is_a?(Array) && parsed['response'].first.is_a?(Hash)
      parsed['response'].first
    else
      parsed
    end
  end

  def apply_webhook(events)
    webhook_url = channel.inbox&.callback_webhook_url
    return if webhook_url.blank?

    instance_post("/webhook/set/#{instance_name}", webhook_payload(webhook_url, events))
  rescue StandardError => e
    Rails.logger.warn("Evolution apply webhook failed: #{e.class}: #{e.message}")
  end

  def webhook_payload(url, events = DEFAULT_EVENTS)
    {
      webhook: {
        enabled: true,
        url: url,
        byEvents: false,
        base64: true,
        events: Array(events).map(&:to_s)
      }
    }
  end

  def send_attachment_message(number, message)
    attachment = message.attachments.first
    id = outbound_message_id(message)
    bytes = attachment.file.download
    base64 = Base64.strict_encode64(bytes)
    file_type = attachment.file_type.to_s
    mimetype = attachment.file.content_type.to_s
    filename = attachment.file.filename.to_s

    response = if file_type == 'audio'
                 send_audio(number, base64, mimetype)
               else
                 media_type = %w[image video document].include?(file_type) ? file_type : 'document'
                 payload = {
                   number: number,
                   mediatype: media_type,
                   mimetype: mimetype.presence || 'application/octet-stream',
                   media: base64,
                   fileName: filename.presence || 'attachment'
                 }
                 payload[:caption] = message.outgoing_content if message.outgoing_content.present? && media_type != 'audio'
                 instance_post("/message/sendMedia/#{instance_name}", payload)
               end

    process_response(response, message, id)
  end

  def send_audio(number, base64, mimetype)
    response = instance_post("/message/sendWhatsAppAudio/#{instance_name}", { number: number, audio: base64 })
    return response if response.success?

    instance_post(
      "/message/sendMedia/#{instance_name}",
      { number: number, mediatype: 'audio', mimetype: mimetype.presence || 'audio/ogg', media: base64, fileName: 'audio.ogg' }
    )
  end

  def interactive_payload(message)
    attrs = message.content_attributes || {}
    data = attrs['interactive'] || attrs[:interactive]
    return nil unless data.is_a?(Hash) || data.is_a?(ActiveSupport::HashWithIndifferentAccess)
    return nil if data['buttons'].blank? && data['sections'].blank?

    data
  end

  def send_interactive_message(number, message, data)
    type = (data['type'] || 'buttons').to_s
    type == 'list' ? send_list_message(number, message, data) : send_buttons_message(number, message, data)
  end

  def send_buttons_message(number, message, data)
    id = outbound_message_id(message)
    buttons = Array(data['buttons']).filter_map do |button|
      title = button['title'].to_s.strip
      next if title.blank?

      { type: 'reply', displayText: title, id: (button['id'] || title).to_s }
    end
    return send_text_message(number, message) if buttons.empty?

    payload = {
      number: number,
      title: (data['header'] || data['body'] || message.outgoing_content).to_s.strip.presence || 'Escolha uma opção:',
      description: (data['body'] || message.outgoing_content).to_s.strip,
      footer: data['footer'].to_s,
      buttons: buttons
    }
    response = instance_post("/message/sendButtons/#{instance_name}", payload)
    return process_response(response, message, id) if response.success?

    send_text_message(number, message, buttons_fallback_text(data, message))
  end

  def send_list_message(number, message, data)
    id = outbound_message_id(message)
    sections = Array(data['sections']).filter_map do |section|
      rows = Array(section['rows']).filter_map do |row|
        title = row['title'].to_s.strip
        next if title.blank?

        { title: title, description: row['description'].to_s, rowId: (row['id'] || title).to_s }
      end
      next if rows.empty?

      { title: section['title'].to_s, rows: rows }
    end
    return send_text_message(number, message) if sections.empty?

    payload = {
      number: number,
      title: (data['header'] || data['body'] || message.outgoing_content).to_s.strip.presence || 'Selecione uma opção:',
      description: (data['body'] || message.outgoing_content).to_s.strip,
      buttonText: (data['button'] || 'Selecionar').to_s,
      footerText: data['footer'].to_s,
      sections: sections
    }
    response = instance_post("/message/sendList/#{instance_name}", payload)
    return process_response(response, message, id) if response.success?

    send_text_message(number, message, list_fallback_text(data, message))
  end

  def buttons_fallback_text(data, message)
    lines = [(data['body'] || message.outgoing_content).to_s.strip]
    Array(data['buttons']).each_with_index do |button, index|
      title = button['title'].to_s.strip
      lines << "#{index + 1}. #{title}" if title.present?
    end
    lines.compact_blank.join("\n")
  end

  def list_fallback_text(data, message)
    lines = [(data['body'] || message.outgoing_content).to_s.strip]
    Array(data['sections']).each do |section|
      lines << section['title'].to_s if section['title'].present?
      Array(section['rows']).each_with_index do |row, index|
        title = row['title'].to_s.strip
        lines << "#{index + 1}. #{title}" if title.present?
      end
    end
    lines.compact_blank.join("\n")
  end

  def process_response(response, message, id)
    parsed = response.parsed_response
    data = unwrap(parsed)
    failed = !response.success? || (parsed.is_a?(Hash) && parsed['error'] == true) || (data.is_a?(Hash) && data['error'] == true)

    if failed
      handle_error(response, message)
      return nil
    end

    parsed_id = parsed.is_a?(Hash) ? parsed.dig('key', 'id') : nil
    data.dig('key', 'id').presence || parsed_id.presence || id
  end

  def handle_error(response, message)
    Rails.logger.error "[UNOFFICIAL_WHATSAPP][EVOLUTION] #{response.body}"
    return if message.blank?

    parsed = response.parsed_response rescue {}
    message.external_error = (parsed['message'] || parsed['error'] || response.body.to_s.first(255)).to_s
    message.status = :failed
    message.save!
  end

  def outbound_message_id(message)
    message.source_id.presence || "OMNI-#{message.id}-#{SecureRandom.hex(6).upcase}"
  end

  def normalize_number(phone_number)
    phone_number.to_s.gsub(/\D/, '')
  end

  def headers
    { 'Content-Type' => 'application/json', 'apikey' => api_key }
  end

  def instance_get(path)
    HTTParty.get("#{endpoint}#{path}", headers: headers, timeout: 30)
  end

  def instance_post(path, body)
    HTTParty.post("#{endpoint}#{path}", headers: headers, body: body.to_json, timeout: 30)
  end

  def instance_delete(path)
    HTTParty.delete("#{endpoint}#{path}", headers: headers, timeout: 30)
  end

  alias admin_post instance_post
  alias admin_get instance_get
  alias admin_delete instance_delete

  class EvolutionError < StandardError; end
end
