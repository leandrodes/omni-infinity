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
    return unless message_event?
    return if echo? || group_message?

    set_contact
    set_conversation

    @message = @conversation.messages.build(
      content: message_content,
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

  private

  def event
    @event ||= params['event'] || params[:event] || {}
  end

  def info
    @info ||= event['Info'] || event[:Info] || {}
  end

  def wa_message
    @wa_message ||= event['Message'] || event[:Message] || {}
  end

  def message_event?
    (params['type'] || params[:type]).to_s == 'Message'
  end

  def echo?
    truthy?(info['IsFromMe'] || info[:IsFromMe])
  end

  def group_message?
    truthy?(info['IsGroup'] || info[:IsGroup])
  end

  def sender_jid
    (info['Sender'] || info[:Sender]).to_s
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
    @media ||= params['base64'] || params[:base64]
  end

  def media_type
    (params['mimeType'] || params[:mimeType]).to_s
  end

  def media_filename
    (params['fileName'] || params[:fileName]).to_s
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
    %w[imageMessage videoMessage documentMessage].each do |key|
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
