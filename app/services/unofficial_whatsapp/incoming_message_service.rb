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

  def perform
    type = (root['type'] || root[:type]).to_s
    case type
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

  def media_filename
    (root['fileName'] || root[:fileName] || params['fileName'] || params[:fileName]).to_s
  end

  def attach_media
    return if media.blank?

    io = StringIO.new(Base64.decode64(media))
    file_type = file_type_for_mime(media_type)

    @message.attachments.new(
      account_id: @message.account_id,
      file_type: file_type,
      file: {
        io: io,
        filename: media_filename.presence || "attachment.#{default_extension_for(file_type)}",
        content_type: media_type
      }
    )
  end

  def file_type_for_mime(mime)
    case mime
    when %r{\Aimage/} then 'image'
    when %r{\Avideo/} then 'video'
    when %r{\Aaudio/} then 'audio'
    else 'file'
    end
  end

  def default_extension_for(file_type)
    { 'image' => 'jpg', 'video' => 'mp4', 'audio' => 'ogg' }[file_type] || 'bin'
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
