#######################################
# Base class for unofficial WhatsApp providers (WuzAPI and friends).
# Child classes implement the session/provisioning API used to pair a
# phone via QR code and to send/receive messages.
#
# Use with UnofficialWhatsapp::Providers::WuzapiService.new(channel: channel).
######################################

class UnofficialWhatsapp::Providers::BaseService
  pattr_initialize [:channel!]

  def provider_name
    channel.provider
  end

  # Provisions a new remote session for this channel and returns the remote
  # user token + id. Implementations return { token:, id: }.
  def create_session(_name:, _webhook:, _events:)
    raise 'Overwrite this method in child class'
  end

  def connect(_events: nil)
    raise 'Overwrite this method in child class'
  end

  # Recovers an existing session. Providers can override this to restart the
  # remote socket instead of only re-issuing the pairing request.
  def reconnect(events: nil)
    return connect if events.nil?

    connect(events: events)
  end

  def qrcode
    raise 'Overwrite this method in child class'
  end

  def status
    raise 'Overwrite this method in child class'
  end

  def set_webhook(_url)
    raise 'Overwrite this method in child class'
  end

  def send_message(_phone_number, _message)
    raise 'Overwrite this method in child class'
  end

  def mark_messages_as_read(_phone_number, _message_ids)
    nil
  end

  def delete_message(_message)
    nil
  end

  protected

  def whatsapp_jid(phone_number)
    value = phone_number.to_s
    return value if value.include?('@')

    "#{value.gsub(/\D/, '')}@s.whatsapp.net"
  end

  def block_contact(_phone_number)
    raise 'Overwrite this method in child class'
  end

  def unblock_contact(_phone_number)
    raise 'Overwrite this method in child class'
  end

  def logout
    raise 'Overwrite this method in child class'
  end

  def disconnect
    raise 'Overwrite this method in child class'
  end

  def delete_session(_remote_id)
    raise 'Overwrite this method in child class'
  end

  def validate_provider_config?
    false
  end
end
