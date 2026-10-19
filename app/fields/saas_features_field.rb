require 'administrate/field/base'

# Community-edition replacement for the enterprise AccountFeaturesField.
# Renders the Infinity SaaS toggles (Funcionalidades / Recursos de IA) plus
# every other feature flag so that saving the account never drops existing
# flags. The submitted param is `enabled_features[feature_<name>]`, which is
# already consumed by SuperAdmin::AccountsController#resource_params.
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
    saas_ai_transcription
  ].freeze

  SAAS_FEATURES = (FUNCTIONALITY_FEATURES + AI_FEATURES).freeze

  def to_s
    data
  end
end
