module SuperAdmin::NavigationHelper
  def settings_open?
    params[:controller].in? %w[super_admin/settings super_admin/app_configs]
  end

  def settings_pages
    features = SuperAdmin::FeaturesHelper.available_features.select do |_feature, attrs|
      attrs['config_key'].present? && attrs['enabled']
    end

    # Add general at the beginning
    general_feature = [['general', { 'config_key' => 'general', 'name' => 'Geral' }]]

    general_feature + features.to_a
  end

  # Nome de exibição de uma seção de configuração (usado nos títulos das telas).
  def settings_page_title(config_key)
    page = settings_pages.find { |_key, attrs| attrs['config_key'] == config_key }
    page&.last&.dig('name') || config_key.to_s.titleize
  end
end
