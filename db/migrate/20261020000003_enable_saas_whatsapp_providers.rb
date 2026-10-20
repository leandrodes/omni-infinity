class EnableSaasWhatsappProviders < ActiveRecord::Migration[7.2]
  DEFAULT_FEATURES = %w[saas_channel_wuzapi saas_channel_evolution].freeze

  def up
    update_default_feature_config

    Account.reset_column_information
    Account.find_each do |account|
      account.enable_features!(*DEFAULT_FEATURES)
    end
  end

  def down
    # Mantém as features habilitadas. Desabilitar poderia derrubar caixas em uso.
  end

  private

  def update_default_feature_config
    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    return if config.blank?

    features = config.value
    DEFAULT_FEATURES.each do |name|
      entry = features.find { |feature| feature['name'] == name }
      if entry
        entry['enabled'] = true
      else
        features << { 'name' => name, 'display_name' => name, 'enabled' => true }
      end
    end
    config.update!(value: features)
  end
end
