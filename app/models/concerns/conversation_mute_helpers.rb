module ConversationMuteHelpers
  extend ActiveSupport::Concern

  def mute!
    return unless contact

    resolved!
    ::Contacts::BlockService.new(contact: contact, blocked: true).perform
    create_muted_message
  end

  def unmute!
    return unless contact

    ::Contacts::BlockService.new(contact: contact, blocked: false).perform
    create_unmuted_message
  end

  def muted?
    contact&.blocked? || false
  end
end
