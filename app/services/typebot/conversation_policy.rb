# frozen_string_literal: true

module Typebot
  class ConversationPolicy
    HANDOFF_KEY = 'typebot_handoff'
    BOT_TEAM_KEY = 'typebot_bot_team_id'

    def self.bot_enabled?(conversation)
      return false if conversation.nil?
      return false if handoff?(conversation)
      return false if conversation.assignee_id.present?
      return false if conversation.team_id.present? && !bot_team?(conversation)

      true
    end

    def self.bot_team?(conversation)
      return false if conversation.team_id.blank?
      return false if conversation.assignee_agent_bot_id.blank? && conversation.ai_assignee_type.blank?

      attributes = conversation.custom_attributes
      return false unless attributes.respond_to?(:[])

      team_id = attributes[BOT_TEAM_KEY] || attributes[BOT_TEAM_KEY.to_sym]
      team_id.present? && team_id.to_i == conversation.team_id
    end

    def self.handoff?(conversation)
      attributes = conversation.custom_attributes
      return false unless attributes.respond_to?(:[])

      attributes[HANDOFF_KEY].present? || attributes[:typebot_handoff].present?
    end

    def self.mark_bot_team!(conversation, team_id)
      attributes = (conversation.custom_attributes || {}).merge(BOT_TEAM_KEY => team_id)
      conversation.update!(team_id: team_id, custom_attributes: attributes)
    end

    def self.mark_handoff!(conversation, team_id: nil, agent_id: nil)
      conversation.reload
      attributes = (conversation.custom_attributes || {}).except(BOT_TEAM_KEY, BOT_TEAM_KEY.to_sym).merge(
        HANDOFF_KEY => true,
        'typebot_handoff_at' => Time.current.iso8601,
        'typebot_handoff_team_id' => team_id,
        'typebot_handoff_agent_id' => agent_id
      ).compact
      conversation.update!(custom_attributes: attributes)
    end
  end
end
