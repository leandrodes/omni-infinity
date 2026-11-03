class SmartReception::ConversationPolicy
  HANDOFF_KEY = 'smart_reception_handoff'.freeze

  class << self
    def available?(conversation)
      return false if conversation.blank?
      return false if handoff?(conversation)
      return false if conversation.assignee_id.present?
      return false if conversation.assignee_agent_bot_id.present?
      return false if conversation.ai_assignee_type.present?
      return false if conversation.team_id.present?

      true
    end

    def mark_handoff!(conversation, team_id: nil, label_id: nil)
      attributes = (conversation.custom_attributes || {}).merge(
        HANDOFF_KEY => true,
        'smart_reception_handoff_at' => Time.current.iso8601,
        'smart_reception_handoff_team_id' => team_id,
        'smart_reception_handoff_label_id' => label_id
      ).compact
      conversation.update!(custom_attributes: attributes)
    end

    private

    def handoff?(conversation)
      attributes = conversation.custom_attributes
      return false unless attributes.respond_to?(:[])

      attributes[HANDOFF_KEY].present? || attributes[HANDOFF_KEY.to_sym].present?
    end
  end
end
