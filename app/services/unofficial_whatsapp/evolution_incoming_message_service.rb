# Processes inbound Evolution API webhooks into Chatwoot conversations.
#
# Evolution sends events such as:
#   { "event": "messages.upsert", "instance": "...", "data": { "key": {...}, "message": {...} } }
#   { "event": "messages.update", "data": [{ "key": {...}, "update": { "status": 3 } }] }
#   { "event": "connection.update", "data": { "state": "open" } }
class UnofficialWhatsapp::EvolutionIncomingMessageService
  pattr_initialize [:inbox!, :params!]

  STATUS_MAP = {
    3 => 'delivered',
    4 => 'read',
    5 => 'read'
  }.freeze

  STATUS_LABELS = {
    'SERVER_ACK' => 'sent',
    'DELIVERY_ACK' => 'delivered',
    'READ' => 'read',
    'PLAYED' => 'read',
    'ERROR' => 'failed'
  }.freeze

  DEFAULT_OVERSIZED_MESSAGE = 'Um arquivo foi recebido, mas não pôde ser processado por exceder o limite de tamanho permitido. Solicite o reenvio por outro meio.'.freeze

  def perform
    case event_name
    when 'messages.upsert'
      handle_message
    when 'messages.update'
      handle_status_update
    when 'connection.update'
      handle_connection_update
    end
  end

  private

  def root
    @root ||= begin
      raw = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params
      raw.deep_stringify_keys
    end
  end

  def event_name
    root['event'].to_s.downcase
  end

  def channel
    @channel ||= inbox.channel
  end

  def data
    root['data']
  end

  def handle_message
    payload = data.is_a?(Array) ? data.first : data
    return unless payload.is_a?(Hash)

    key = payload['key'] || {}
    return if truthy?(key['fromMe'])

    remote_jid = alternative_jid(key) || key['remoteJid'].to_s
    return if remote_jid.blank?

    group = remote_jid.end_with?('@g.us')
    return if group && channel.ignore_groups

    sender_jid = if group
                   alternative_jid(key, 'participantAlt') || (key['participant'] || payload['participant']).to_s
                 else
                   remote_jid
                 end
    return if sender_jid.blank?

    message_node = normalize_message_node(payload['message'])
    text = extract_text(message_node)
    media = extract_media(message_node, key)

    return if text.blank? && media.blank?

    set_contact(sender_jid, payload['pushName'])
    set_conversation

    return handle_oversized_media(media, text) if media.present? && media_exceeds_limit?(media)

    content = if media.present? && media[:base64].blank?
                media[:caption].presence || text.presence || '[mídia recebida]'
              else
                media&.dig(:caption).presence || text
              end

    @message = @conversation.messages.build(
      content: content,
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      message_type: :incoming,
      sender: @contact,
      source_id: key['id'].to_s,
      content_attributes: {}
    )

    attach_media(media) if media.present?
    @message.save!
  end

  def handle_status_update
    updates = data.is_a?(Array) ? data : [data]
    updates.each do |update|
      next unless update.is_a?(Hash)

      status = status_from(update)
      next if status.blank?

      message_ids = message_ids_from(update)
      next if message_ids.empty?

      Message.where(inbox_id: inbox.id, source_id: message_ids, message_type: :outgoing).find_each do |message|
        Messages::StatusUpdateService.new(message, status).perform
      end
    end
  end

  def status_from(update)
    raw = update.dig('update', 'status') || update['status']
    return if raw.blank?
    return STATUS_MAP[raw.to_i] if raw.to_s.match?(/\A\d+\z/)

    STATUS_LABELS[raw.to_s.upcase]
  end

  def message_ids_from(update)
    [update.dig('key', 'id'), update['keyId']].compact_blank.uniq
  end

  def alternative_jid(key, field = 'remoteJidAlt')
    key[field].presence || key['senderPn'].presence
  end

  def handle_connection_update
    payload = data.is_a?(Array) ? data.first : data
    return unless payload.is_a?(Hash)

    state = (payload['state'] || payload.dig('instance', 'state')).to_s.downcase
    new_status = case state
                 when 'open' then 'connected'
                 when 'connecting' then 'connecting'
                 when 'close' then 'disconnected'
                 end
    return if new_status.blank? || channel.connection_status == new_status

    channel.update!(connection_status: new_status)
  end

  def normalize_message_node(message)
    node = message.is_a?(Hash) ? message : {}
    %w[ephemeralMessage viewOnceMessage viewOnceMessageV2 viewOnceMessageV2Extension].each do |wrapper|
      nested = node.dig(wrapper, 'message')
      node = nested if nested.is_a?(Hash)
    end
    node
  end

  def extract_text(node)
    (node['conversation']).presence ||
      node.dig('extendedTextMessage', 'text').presence ||
      button_reply(node).presence ||
      list_reply(node).presence ||
      template_button_reply(node).presence ||
      ''
  end

  def button_reply(node)
    reply = node['buttonsResponseMessage']
    return nil if reply.blank?

    reply['selectedButtonId'].presence || reply['selectedDisplayText']
  end

  def list_reply(node)
    reply = node['listResponseMessage']
    return nil if reply.blank?

    reply.dig('singleSelectReply', 'selectedRowId').presence || reply['title']
  end

  def template_button_reply(node)
    reply = node['templateButtonReplyMessage']
    return nil if reply.blank?

    reply['selectedID'].presence || reply['selectedId'].presence || reply['selectedDisplayText']
  end

  def extract_media(node, key)
    media_node, file_type = media_node_for(node)
    return nil if media_node.blank?

    base64 = media_base64(node, media_node)
    base64 ||= channel.provider_service.fetch_media_base64(key) if channel.provider_service.respond_to?(:fetch_media_base64)
    base64 = strip_data_uri(base64)

    {
      base64: base64,
      file_type: file_type,
      mime_type: media_node['mimetype'].to_s,
      caption: media_node['caption'].to_s,
      filename: media_filename(media_node, file_type)
    }
  end

  def media_node_for(node)
    return [node['imageMessage'], :image] if node['imageMessage']
    return [node['stickerMessage'], :image] if node['stickerMessage']
    return [node['videoMessage'], :video] if node['videoMessage']
    return [node['audioMessage'], :audio] if node['audioMessage']
    return [node['documentMessage'], :file] if node['documentMessage']

    nil
  end

  def media_base64(node, media_node)
    media_node['base64'].presence ||
      node['base64'].presence ||
      (data.is_a?(Hash) ? data['base64'].presence : nil)
  end

  def strip_data_uri(value)
    value.to_s.sub(%r{\Adata:[^;]+;base64,}, '').presence
  end

  def media_filename(media_node, file_type)
    name = media_node['fileName'].presence || media_node['title'].presence
    extension = extension_for(media_node['mimetype'].to_s, file_type)
    return name if name.present? && extension.blank?

    stem = name.present? ? File.basename(name, '.*') : 'attachment'
    "#{stem}.#{extension}"
  end

  def extension_for(mime, file_type)
    case mime.to_s.downcase.split(';').first.to_s.strip
    when 'image/jpeg', 'image/jpg' then 'jpg'
    when 'image/png' then 'png'
    when 'image/webp' then 'webp'
    when 'image/gif' then 'gif'
    when 'video/mp4' then 'mp4'
    when 'video/3gpp' then '3gp'
    when 'audio/ogg', 'application/ogg', 'audio/opus' then 'ogg'
    when 'audio/mpeg' then 'mp3'
    when 'audio/mp4', 'audio/aac' then 'm4a'
    when 'text/plain' then 'txt'
    when 'application/pdf' then 'pdf'
    when 'application/zip' then 'zip'
    else
      { image: 'jpg', video: 'mp4', audio: 'ogg' }[file_type] || 'bin'
    end
  end

  def attach_media(media)
    return if media[:base64].blank?

    io = StringIO.new(Base64.decode64(media[:base64]))
    file_type = media[:file_type]
    content_type = media[:mime_type].presence || default_content_type(file_type)
    content_type = 'audio/ogg' if file_type == :audio && content_type == 'application/ogg'

    file = {
      io: io,
      filename: media[:filename].presence || "attachment.#{extension_for(content_type, file_type)}",
      content_type: content_type
    }
    file[:identify] = false if file_type == :audio

    @message.attachments.new(
      account_id: @message.account_id,
      file_type: file_type,
      file: file
    )
  end

  def default_content_type(file_type)
    { image: 'image/jpeg', video: 'video/mp4', audio: 'audio/ogg' }[file_type] || 'application/octet-stream'
  end

  def set_contact(sender_jid, push_name)
    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: phone_number(sender_jid),
      inbox: inbox,
      contact_attributes: {
        name: push_name.presence || phone_number(sender_jid),
        phone_number: "+#{phone_number(sender_jid)}",
        additional_attributes: { phone: phone_number(sender_jid) }
      }
    ).perform

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact
  end

  def set_conversation
    @conversation = if inbox.lock_to_single_conversation
                      @contact_inbox.conversations.last
                    else
                      @contact_inbox.conversations.where.not(status: :resolved).last
                    end
    return if @conversation

    @conversation = ::Conversation.create!(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id
    )
  end

  # "5511999999999:12@s.whatsapp.net" -> "5511999999999"
  def phone_number(jid)
    jid.to_s.split('@').first.split(/[.:]/).first
  end

  def media_exceeds_limit?(media)
    media_size_bytes(media) > max_upload_size_bytes
  end

  def media_size_bytes(media)
    (media[:base64].to_s.bytesize * 3) / 4
  end

  def max_upload_size_bytes
    limit_mb = GlobalConfigService.load('MAXIMUM_FILE_UPLOAD_SIZE', 40).to_i
    limit_mb = 40 if limit_mb <= 0
    limit_mb.megabytes
  end

  def handle_oversized_media(media, caption)
    text = oversized_message_text
    lines = [
      "Arquivo recebido acima do limite: #{media[:filename].presence || 'arquivo'} (#{ActiveSupport::NumberHelper.number_to_human_size(media_size_bytes(media))}).",
      "O anexo não foi processado (limite atual: #{ActiveSupport::NumberHelper.number_to_human_size(max_upload_size_bytes)})."
    ]
    lines << "Legenda: #{caption}" if caption.present?
    lines << ''
    lines << text

    @conversation.messages.create!(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      message_type: :outgoing,
      private: true,
      content: lines.join("\n")
    )
    @conversation.messages.create!(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      message_type: :outgoing,
      content: text
    )
  end

  def oversized_message_text
    configured = GlobalConfigService.load('FILE_TOO_LARGE_MESSAGE', nil).to_s.strip
    configured.presence || DEFAULT_OVERSIZED_MESSAGE
  end

  def truthy?(value)
    value == true || value.to_s == 'true'
  end
end
