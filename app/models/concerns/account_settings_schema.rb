module AccountSettingsSchema
  extend ActiveSupport::Concern

  CAPTAIN_MODEL_PROPERTIES = Llm::Models.model_feature_keys.index_with { { 'type': %w[string null] } }.freeze
  CAPTAIN_FEATURE_PROPERTIES = Llm::Models.feature_keys.index_with { { 'type': %w[boolean null] } }.freeze

  SETTINGS_PARAMS_SCHEMA = {
    'type': 'object',
    'properties':
      {
        'auto_resolve_after': { 'type': %w[integer null], 'minimum': 10, 'maximum': 1_439_856 },
        'auto_resolve_message': { 'type': %w[string null] },
        'auto_resolve_ignore_waiting': { 'type': %w[boolean null] },
        'audio_transcriptions': { 'type': %w[boolean null] },
        'signature_enabled': { 'type': %w[boolean null] },
        'signature_agents_can_disable': { 'type': %w[boolean null] },
        'auto_resolve_label': { 'type': %w[string null] },
        'keep_pending_on_bot_failure': { 'type': %w[boolean null] },

        'enable_chatbot_conversations_filter': { 'type': %w[boolean null] },
        'enable_resolved_conversations_filter': { 'type': %w[boolean null] },
        'show_inbox_name_in_conversation_list': { 'type': %w[boolean null] },
        'show_conversation_id_in_conversation_list': { 'type': %w[boolean null] },
        'show_conversation_status_in_conversation_list': { 'type': %w[boolean null] },
        'list_only_last_resolved_conversation_per_contact': { 'type': %w[boolean null] },
        'hide_conversations_assigned_to_others': { 'type': %w[boolean null] },
        'hide_resolved_conversations_assigned_to_others': { 'type': %w[boolean null] },
        'show_conversations_only_from_user_teams': { 'type': %w[boolean null] },
        'agents_can_reopen_conversations': { 'type': %w[boolean null] },
        'agents_can_join_conversations_as_participant': { 'type': %w[boolean null] },
        'ignore_whatsapp_groups': { 'type': %w[boolean null] },
        'enable_whatsapp_groups_filter': { 'type': %w[boolean null] },
        'allow_create_whatsapp_groups': { 'type': %w[boolean null] },
        'allow_end_whatsapp_groups': { 'type': %w[boolean null] },
        'allow_transfer_whatsapp_groups': { 'type': %w[boolean null] },
        'reactions_appear_as_response': { 'type': %w[boolean null] },
        'conversation_filter_limits': { 'type': %w[object null] },
        'captain_auto_resolve_mode': { 'type': %w[string null], 'enum': ['evaluated', 'legacy', 'disabled', nil] },
        'captain_false_promise_harness_enabled': { 'type': %w[boolean null] },
        'conversation_required_attributes': {
          'type': %w[array null],
          'items': { 'type': 'string' }
        },
        'captain_models': {
          'type': %w[object null],
          'properties': CAPTAIN_MODEL_PROPERTIES,
          'additionalProperties': false
        },
        'captain_features': {
          'type': %w[object null],
          'properties': CAPTAIN_FEATURE_PROPERTIES,
          'additionalProperties': false
        }
      },
    'required': [],
    'additionalProperties': true
  }.to_json.freeze
end
