require 'administrate/field/base'

# Community-edition replacement for the enterprise AccountFeaturesField.
# Renders the Infinity SaaS toggles (Funcionalidades / Recursos de IA) plus the
# community-safe feature flags. Enterprise-only (premium) flags are hidden from
# this form on purpose — see RECURSOS_ENTERPRISE_REMOVIDOS.txt.
class SaasFeaturesField < Administrate::Field::Base
  FUNCTIONALITY_FEATURES = %w[
    saas_groups
    saas_campaigns
    saas_channel_wuzapi
    saas_channel_evolution
    saas_channel_uzapi
    saas_channel_wacalls
  ].freeze

  AI_FEATURES = %w[
    saas_ai_copilot
    saas_ai_smart_reception
  ].freeze

  # "Transcrição de Áudio" is backed by accounts.transcription_allow_system so
  # that toggling it controls the internal (system) Whisper directly. The flag
  # is kept out of the rendered lists to avoid a duplicated toggle.
  TRANSCRIPTION_FLAG = 'saas_ai_transcription'

  SAAS_FEATURES = (FUNCTIONALITY_FEATURES + AI_FEATURES + [TRANSCRIPTION_FLAG]).freeze

  # Features that either already have their own SaaS toggle or are Captain/
  # enterprise-adjacent and should not show up under "Outras funcionalidades".
  HIDDEN_OTHER_FEATURES = (SAAS_FEATURES + %w[
    campaigns captain_tasks
    captain_integration captain_integration_v2
    linear_integration notion_integration channel_tiktok
    shopify_integration whatsapp_embedded_signup
    whatsapp_embedded_signup_inbox_creation
  ]).freeze

  OTHER_FEATURE_LABELS = {
    'inbound_emails' => 'E-mails recebidos',
    'channel_email' => 'Canal de E-mail',
    'channel_facebook' => 'Canal do Facebook',
    'ip_lookup' => 'Consulta de IP',
    'email_continuity_on_api_channel' => 'Continuidade de e-mail no canal API',
    'help_center' => 'Central de Ajuda',
    'agent_bots' => 'Agentes Bots',
    'macros' => 'Macros',
    'agent_management' => 'Gerenciamento de agentes',
    'team_management' => 'Gerenciamento de equipes',
    'inbox_management' => 'Gerenciamento de caixas de entrada',
    'labels' => 'Etiquetas',
    'custom_attributes' => 'Atributos personalizados',
    'automations' => 'Automações',
    'canned_responses' => 'Respostas prontas',
    'integrations' => 'Integrações',
    'voice_recorder' => 'Gravador de voz',
    'report_rollup' => 'Consolidação de relatórios',
    'channel_website' => 'Canal de site',
    'reports' => 'Relatórios',
    'crm' => 'CRM',
    'auto_resolve_conversations' => 'Resolução automática de conversas',
    'custom_reply_email' => 'E-mail de resposta personalizado',
    'custom_reply_domain' => 'Domínio de resposta personalizado',
    'branded_email_templates' => 'Modelos de e-mail com marca',
    'chatwoot_v4' => 'Chatwoot V4',
    'channel_instagram' => 'Canal do Instagram',
    'crm_integration' => 'Integração de CRM',
    'whatsapp_campaign' => 'Campanha de WhatsApp',
    'assignment_v2' => 'Atribuição V2',
    'whatsapp_manual_transfer' => 'Transferência manual de WhatsApp',
    'data_import' => 'Importação de dados',
    'api_and_webhooks' => 'API e Webhooks',
    'delayed_automations' => 'Automações com atraso'
  }.freeze

  def to_s
    data
  end

  # Community-safe flags only: no premium (enterprise), no internal/deprecated,
  # no SaaS duplicates.
  def other_features
    @other_features ||= begin
      premium = SuperAdmin::AccountFeaturesHelper.account_premium_features
      SuperAdmin::AccountFeaturesHelper.filtered_features(data)
        .reject do |key_array, _value|
          key = key_array.first
          HIDDEN_OTHER_FEATURES.include?(key) || premium.include?(key)
        end
    end
  end

  def label_for(feature_key, fallback = nil)
    OTHER_FEATURE_LABELS[feature_key] || fallback || feature_key.humanize
  end
end
