# Processes inbound WuzAPI webhooks (whatsmeow events.Message payload) into
# Chatwoot conversations/messages. The payload looks like:
#
#   {
#     "event": { "Info": {...}, "Message": { "conversation": "...", ... } },
#     "type": "Message",
#     "base64": "<base64 media>",   # present when media_delivery includes base64
#     "mimeType": "image/jpeg",
#     "fileName": "..."
#   }
class UnofficialWhatsapp::IncomingMessageService
  pattr_initialize [:inbox!, :params!]

  # whatsmeow receipt types -> Chatwoot message status.
  # "played" is a voice note/audio "read" and maps to read as well.
  RECEIPT_STATUS_MAP = {
    'delivered' => 'delivered',
    'read' => 'read',
    'played' => 'read'
  }.freeze

  DEFAULT_OVERSIZED_MESSAGE = 'Um arquivo foi recebido, mas não pôde ser processado por exceder o limite de tamanho permitido. Solicite o reenvio por outro meio.'.freeze

  def perform
    type = (root['type'] || root[:type]).to_s
    case type
    when 'ReadReceipt', 'Receipt'
      return handle_receipt
    when 'CallOffer', 'CallOfferNotice'
      return handle_call_offer unless type == 'CallOfferNotice'
      return
    when 'Message'
      nil
    else
      return
    end

    return if echo?
    return if group_message? && channel.ignore_groups

    content = message_content
    return if content.blank? && media.blank?

    set_contact
    set_conversation

    return handle_oversized_media(content) if media.present? && media_exceeds_limit?

    @message = @conversation.messages.build(
      content: content,
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :incoming,
      sender: @contact,
      source_id: source_id,
      content_attributes: {}
    )

    attach_media
    @message.save!
  end

  # whatsmeow delivers delivery/read acknowledgements as a `Receipt` event whose
  # payload is the raw `events.Receipt` (MessageIDs, Chat, Sender, Type). We map
  # it onto the outgoing message status so the UI reflects the tick progression.
  def handle_receipt
    status = RECEIPT_STATUS_MAP[receipt_type]
    return if status.blank?

    message_ids = receipt_message_ids
    return if message_ids.empty?

    Message.where(inbox_id: @inbox.id, source_id: message_ids, message_type: :outgoing).find_each do |message|
      Messages::StatusUpdateService.new(message, status).perform
    end
  end

  # Media that exceeds the configured upload limit is not attached. Instead we
  # leave a private note for the agents and send an automatic reply to the
  # contact explaining the situation (text configured in Super-Admin > General).
  def handle_oversized_media(caption)
    text = oversized_message_text
    create_private_note(oversized_note_content(caption, text))
    create_auto_reply(text)
  end

  def oversized_message_text
    configured = GlobalConfigService.load('FILE_TOO_LARGE_MESSAGE', nil).to_s.strip
    configured.presence || DEFAULT_OVERSIZED_MESSAGE
  end

  def oversized_note_content(caption, text)
    lines = [
      "Arquivo recebido acima do limite: #{media_filename.presence || 'arquivo'} (#{human_media_size}).",
      "O anexo não foi processado (limite atual: #{human_max_upload_size})."
    ]
    lines << "Legenda: #{caption}" if caption.present?
    lines << ''
    lines << text
    lines.join("\n")
  end

  def create_private_note(content)
    @conversation.messages.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :outgoing,
      private: true,
      content: content
    )
  end

  def create_auto_reply(content)
    @conversation.messages.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :outgoing,
      content: content
    )
  end

  def media_exceeds_limit?
    media_size_bytes > max_upload_size_bytes
  end

  # The base64 string is ~4/3 of the decoded binary size; good enough to decide
  # whether we should skip decoding/attaching a huge payload.
  def media_size_bytes
    @media_size_bytes ||= (media.to_s.bytesize * 3) / 4
  end

  def max_upload_size_bytes
    limit_mb = GlobalConfigService.load('MAXIMUM_FILE_UPLOAD_SIZE', 40).to_i
    limit_mb = 40 if limit_mb <= 0

    limit_mb.megabytes
  end

  def human_media_size
    ActiveSupport::NumberHelper.number_to_human_size(media_size_bytes)
  end

  def human_max_upload_size
    ActiveSupport::NumberHelper.number_to_human_size(max_upload_size_bytes)
  end

  def handle_call_offer
    return unless channel.block_calls

    reject_call!
    text = channel.call_block_message.presence || 'Este número está bloqueado para receber chamadas'

    set_contact
    set_conversation

    @message = @conversation.messages.build(
      content: text,
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :incoming,
      sender: @contact,
      source_id: source_id,
      content_attributes: {}
    )
    @message.save!
  end

  private

  def channel
    @channel ||= @inbox.channel
  end

  # For `Receipt` events the payload under `event` is the receipt itself
  # (not wrapped in Info/Message like the `Message` event).
  def receipt
    @receipt ||= event
  end

  # WuzAPI exposes the acknowledgement kind at the top level (`state`) as
  # Delivered/Read/ReadSelf, while the raw whatsmeow `event.Type` holds
  # delivered/read/read-self/played. Prefer the top-level value.
  def receipt_type
    (root['state'] || root[:state] || receipt['Type'] || receipt[:Type]).to_s.downcase
  end

  def receipt_message_ids
    Array(receipt['MessageIDs'] || receipt[:MessageIDs] || receipt['Ids'] || receipt[:Ids]).map(&:to_s).compact_blank
  end

  def reject_call!
    @inbox.channel.provider_service.reject_call(call_from: sender_jid, call_id: call_identifier)
  rescue StandardError => e
    Rails.logger.warn("WuzAPI inbound call reject failed: #{e.class}: #{e.message}")
  end

  def call_identifier
    (info['CallID'] || info[:CallID] || info['ID'] || info[:ID] || root['call_id'] || root[:call_id]).to_s
  end

  # WuzAPI posts the actual event as a JSON *string* under `jsonData`:
  #   { "instanceName": "...", "userID": "...",
  #     "jsonData": "{\"event\":{...},\"type\":\"Message\"}" }
  # Fall back to the raw params so the service also accepts unwrapped payloads.
  def root
    @root ||= begin
      raw = params['jsonData'] || params[:jsonData] || params['payload'] || params[:payload]
      raw = raw.is_a?(String) ? JSON.parse(raw) : raw if raw.present?
      raw = params if raw.blank?
      # Some WuzAPI versions might embed the full event under another key
      raw = raw['data'] if raw.is_a?(Hash) && raw.key?('data') && raw['data'].is_a?(Hash) && (raw['data'].key?('event') || raw['data'].key?(:event))
      raw
    rescue JSON::ParserError
      params
    end
  end

  def event
    @event ||= root['event'] || root[:event] || {}
  end

  def info
    @info ||= event['Info'] || event[:Info] || {}
  end

  def wa_message
    @wa_message ||= event['Message'] || event[:Message] || {}
  end

  def message_event?
    (root['type'] || root[:type]).to_s == 'Message'
  end

  def echo?
    truthy?(info['IsFromMe'] || info[:IsFromMe])
  end

  def group_message?
    truthy?(info['IsGroup'] || info[:IsGroup])
  end

  # Contacts that use a LID only expose the real phone number in SenderAlt
  # ("551199...:50@s.whatsapp.net"); Sender carries the "@lid" form.
  def sender_jid
    ((info['SenderAlt'] || info[:SenderAlt]).presence || (info['Sender'] || info[:Sender])).to_s
  end

  def source_id
    (info['ID'] || info[:ID]).to_s
  end

  def push_name
    (info['PushName'] || info[:PushName]).to_s
  end

  def set_contact
    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: phone_number,
      inbox: inbox,
      contact_attributes: contact_attributes
    ).perform

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact
  end

  def contact_attributes
    {
      name: push_name.presence || phone_number,
      phone_number: "+#{phone_number}",
      additional_attributes: { phone: phone_number }
    }
  end

  def set_conversation
    @conversation = if @inbox.lock_to_single_conversation
                      @contact_inbox.conversations.last
                    else
                      @contact_inbox.conversations.where.not(status: :resolved).last
                    end
    return if @conversation

    @conversation = ::Conversation.create!(conversation_params)
  end

  def conversation_params
    {
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id
    }
  end

  def message_content
    return text_content if media.blank?

    caption_from_message || text_content
  end

  def text_content
    (wa_message['conversation'] || wa_message[:conversation]).presence ||
      (wa_message.dig('extendedTextMessage', 'text') || wa_message.dig(:extendedTextMessage, :text)).presence ||
      ''
  end

  def media
    @media ||= root['base64'] || root[:base64] || params['base64'] || params[:base64]
  end

  def media_type
    (root['mimeType'] || root[:mimeType] || params['mimeType'] || params[:mimeType]).to_s
  end

  # The original document name (with the correct extension) lives in the
  # message node. WuzAPI's webhook `fileName` may be an auto-generated name
  # with a wrong extension (e.g. "3EB0....asc" for a .txt).
  def media_filename
    # The document node carries the original file name (with the correct
    # extension). For images/audio/video the node has no name, so we normalize
    # the auto-generated WuzAPI name against the real mime type.
    return node_media_filename if node_media_filename.present?

    normalize_filename(webhook_media_filename)
  end

  def normalize_filename(name)
    name = name.to_s.strip
    ext = extension_for_media
    return name.presence || "attachment.#{default_extension_for(detect_file_type)}" if ext.blank?

    stem = name.present? ? File.basename(name, '.*') : 'attachment'
    "#{stem}.#{ext}"
  end

  def base_mime
    media_type.to_s.downcase.split(';').first.to_s.strip
  end

  def extension_for_media
    case base_mime
    when 'image/jpeg', 'image/jpg' then 'jpg'
    when 'image/png' then 'png'
    when 'image/webp' then 'webp'
    when 'image/gif' then 'gif'
    when 'image/bmp' then 'bmp'
    when 'image/heic' then 'heic'
    when 'image/heif' then 'heif'
    when 'image/avif' then 'avif'
    when 'image/vnd.microsoft.icon', 'image/x-icon' then 'ico'
    when 'video/mp4' then 'mp4'
    when 'video/3gpp' then '3gp'
    when 'audio/ogg', 'application/ogg', 'application/x-ogg', 'audio/opus' then 'ogg'
    when 'audio/mpeg' then 'mp3'
    when 'audio/mp4', 'audio/aac' then 'm4a'
    when 'text/plain' then 'txt'
    when 'text/csv' then 'csv'
    when 'application/pdf' then 'pdf'
    when 'application/zip' then 'zip'
    when %r{\Aimage/} then base_mime.split('/').last
    end
  end

  def node_media_filename
    doc = wa_message['documentMessage'] || wa_message[:documentMessage]
    return nil if doc.blank?

    (doc['title'] || doc[:title] || doc['fileName'] || doc[:fileName]).to_s
  end

  def webhook_media_filename
    (root['fileName'] || root[:fileName] || params['fileName'] || params[:fileName]).to_s
  end

  def attach_media
    return if media.blank?

    io = StringIO.new(Base64.decode64(media))
    file_type = detect_file_type
    file = {
      io: io,
      filename: media_filename.presence || "attachment.#{default_extension_for(file_type)}",
      content_type: content_type_for(file_type)
    }
    # Keep our content type for voice notes (WhatsApp PTT is Opus-in-Ogg): Marcel
    # otherwise re-identifies the blob as "audio/opus", which some browsers
    # refuse to play through the <audio> element.
    file[:identify] = false if file_type == :audio

    @message.attachments.new(
      account_id: @message.account_id,
      file_type: file_type,
      file: file
    )
  end

  # whatsmeow exposes the media kind through the message node (audioMessage,
  # imageMessage, ...). That is far more reliable than the webhook mimeType,
  # which for WhatsApp voice notes arrives as the container type
  # "application/ogg" (not "audio/ogg").
  def detect_file_type
    from_message_node || file_type_for_mime(media_type)
  end

  def from_message_node
    return :audio if wa_message['audioMessage'] || wa_message[:audioMessage]
    return :video if wa_message['videoMessage'] || wa_message[:videoMessage]
    return :file if wa_message['documentMessage'] || wa_message[:documentMessage]
    return :image if wa_message['imageMessage'] || wa_message[:imageMessage] ||
                     wa_message['stickerMessage'] || wa_message[:stickerMessage]

    nil
  end

  def file_type_for_mime(mime)
    normalized = mime.to_s.downcase.split(';').first.to_s.strip
    case normalized
    when %r{\Aimage/} then :image
    when %r{\Avideo/} then :video
    when %r{\Aaudio/} then :audio
    when 'application/ogg', 'application/x-ogg', 'application/opus' then :audio
    else :file
    end
  end

  def content_type_for(file_type)
    return 'audio/ogg' if file_type == :audio && %w[application/ogg application/x-ogg audio/opus].include?(base_mime)

    base_mime.presence
  end

  def default_extension_for(file_type)
    { 'image' => 'jpg', 'video' => 'mp4', 'audio' => 'ogg' }[file_type.to_s] || 'bin'
  end

  def caption_from_message
    %w[imageMessage videoMessage documentMessage audioMessage].each do |key|
      node = wa_message[key] || wa_message[key.underscore.to_sym]
      caption = node&.dig('caption') || node&.dig(:caption)
      return caption if caption.present?
    end
    nil
  end

  # "5491155553935.0:12@s.whatsapp.net" -> "5491155553935"
  def phone_number
    @phone_number ||= sender_jid.split('@').first.split(/[.:]/).first
  end

  def truthy?(value)
    value == true || value.to_s == 'true'
  end
end
