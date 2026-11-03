# frozen_string_literal: true

if ENV.fetch('TYPEBOT_RUNTIME_ENABLED', 'false') == 'true'
  Rails.application.config.after_initialize do
    Message.class_eval do
      unless method_defined?(:enqueue_typebot_runtime)
        after_commit :enqueue_typebot_runtime, on: :create

        private

        # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        def enqueue_typebot_runtime
          return unless incoming?
          return if content_attributes&.dig('bot_response')
          return if content_attributes&.dig('campaign_id')
          return if content.blank?
          return if inbox.out_of_office?
          return unless Typebot::ConversationPolicy.bot_enabled?(conversation)
          return unless Typebot::AgentBotConfig.for_inbox(inbox).valid?

          Typebot::ProcessMessageJob.perform_later(id)
        rescue StandardError => e
          Rails.logger.error("[Typebot] enqueue failed for message #{id}: #{e.message}")
        end
        # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      end
    end
  end
end
