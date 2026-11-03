require 'redis'
require 'securerandom'

# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
class SmartReception::ResponseJob < ApplicationJob
  queue_as :default

  FIRST_MESSAGE_KEY = 'smart_reception:first_message_at:%s'.freeze
  LOCK_KEY = 'smart_reception:conversation:%s'.freeze

  def perform(conversation_id, _message_id = nil)
    conversation = Conversation.find_by(id: conversation_id)
    return unless conversation

    setting = conversation.inbox.smart_reception_setting
    return unless setting&.enabled?
    return unless conversation.account.feature_enabled?('saas_ai_smart_reception')

    redis = Redis.new(Redis::Config.app)
    first_key = format(FIRST_MESSAGE_KEY, conversation.id)

    unless SmartReception::ConversationPolicy.available?(conversation)
      redis.del(first_key)
      return
    end

    latest = latest_incoming_message(conversation)
    if latest.blank? || answered_after?(conversation, latest) || human_replied_after?(conversation, latest)
      redis.del(first_key)
      return
    end

    first_at = redis.get(first_key)
    if first_at.blank?
      first_at = latest.created_at.iso8601
      redis.set(first_key, first_at, ex: setting.max_wait_seconds + 120)
    end

    target = response_target(setting, latest, first_at)
    if Time.current < target
      self.class.set(wait: (target - Time.current).clamp(1, Float::INFINITY)).perform_later(conversation.id, latest.id)
      return
    end

    processed = with_lock(redis, format(LOCK_KEY, conversation.id)) do
      latest = latest_incoming_message(conversation)
      next false if latest.blank? || answered_after?(conversation, latest) || human_replied_after?(conversation, latest)
      next false unless SmartReception::ConversationPolicy.available?(conversation)

      SmartReception::Responder.new(setting: setting.reload, conversation: conversation.reload, message: latest).perform
      true
    end

    redis.del(first_key) if processed
  rescue StandardError => e
    Rails.logger.error("[SmartReception] conversation #{conversation_id} failed: #{e.class}: #{e.message}")
    Rails.logger.error(e.backtrace&.first(8)&.join("\n"))
  ensure
    redis&.close
  end

  private

  def latest_incoming_message(conversation)
    conversation.messages.incoming.where.not(content: [nil, '']).order(:created_at).last
  end

  def answered_after?(conversation, message)
    conversation.messages.outgoing
                .where("content_attributes ->> 'smart_reception' = 'true'")
                .exists?(['created_at > ?', message.created_at])
  end

  def human_replied_after?(conversation, message)
    conversation.messages.outgoing
                .where(sender_type: 'User')
                .exists?(['created_at > ?', message.created_at])
  end

  def response_target(setting, latest, first_at)
    [latest.created_at + setting.min_wait_seconds.seconds, Time.zone.parse(first_at) + setting.max_wait_seconds.seconds].min
  end

  def with_lock(redis, key)
    token = SecureRandom.hex(8)
    return false unless redis.set(key, token, nx: true, ex: 120)

    begin
      yield
    ensure
      redis.del(key) if redis.get(key) == token
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
