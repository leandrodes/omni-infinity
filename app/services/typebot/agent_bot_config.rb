# frozen_string_literal: true

require 'uri'

module Typebot
  class AgentBotConfig
    attr_reader :agent_bot, :public_id

    def self.for_inbox(inbox)
      new(inbox&.agent_bot)
    end

    def self.typebot_url?(url)
      public_id_from_url(url).present?
    end

    def self.public_id_from_url(url)
      uri = URI.parse(url.to_s)
      return if uri.host.blank?
      return unless viewer_host?(uri)

      uri.path.split('/').reject(&:blank?).first.presence
    rescue URI::InvalidURIError
      nil
    end

    def self.viewer_host?(uri)
      configured_host = viewer_host
      return uri.host == configured_host if configured_host.present?

      uri.host.to_s.include?('typebot-viewer')
    end

    def self.viewer_host
      URI.parse(ENV.fetch('TYPEBOT_VIEWER_PUBLIC_URL', '')).host
    rescue URI::InvalidURIError
      nil
    end

    def initialize(agent_bot)
      @agent_bot = agent_bot
      @public_id = self.class.public_id_from_url(agent_bot&.outgoing_url)
    end

    def valid?
      agent_bot.present? && public_id.present?
    end
  end
end
