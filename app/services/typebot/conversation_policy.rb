# frozen_string_literal: true

module Typebot
  class ConversationPolicy
    HANDOFF_KEY = 'typebot_handoff'

    def self.bot_enabled?(conversation)
      return false if conversation.nil?
      return false if handoff?(conversation)
      return false if conversation.assignee_id.present?
      return false if conversation.team_id.present?

      true
    end

    def self.handoff?(conversation)
      attributes = conversation.custom_attributes
      return false unless attributes.respond_to?(:[])

      attributes[HANDOFF_KEY].present? || attributes[:typebot_handoff].present?
    end

    def self.mark_handoff!(conversation, team_id: nil, agent_id: nil)
      conversation.reload
      attributes = (conversation.custom_attributes || {}).merge(
        HANDOFF_KEY => true,
        'typebot_handoff_at' => Time.current.iso8601,
        'typebot_handoff_team_id' => team_id,
        'typebot_handoff_agent_id' => agent_id
      ).compact
      conversation.update!(custom_attributes: attributes)
    end
  end
end
