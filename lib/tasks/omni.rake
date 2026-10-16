# frozen_string_literal: true

# Aplica a identidade "Omni-Channel Infinity" e remove referências à marca original
# ("Chatwoot"/chatwoot.com) em instalações JÁ existentes.
#
# Motivo: o ConfigLoader usa reconcile_only_new=true e portanto NUNCA sobrescreve
# installation_configs que já existem no banco. Assim, mudar config/installation_config.yml
# afeta apenas instalações novas. Esta task reconcilia as instalações existentes,
# alterando SOMENTE valores que ainda estão no padrão antigo (para não destruir
# customizações feitas por um cliente).
namespace :omni do
  desc 'Aplica identidade Omni-Channel Infinity em installation_configs existentes'
  task rebrand: :environment do
    brand_name = 'Omni-Channel Infinity'
    brand_url = 'https://infinitytelecom.com.br'

    rename = {
      'INSTALLATION_NAME' => brand_name,
      'BRAND_NAME' => brand_name
    }

    urls = {
      'BRAND_URL' => brand_url,
      'WIDGET_BRAND_URL' => brand_url,
      'TERMS_URL' => brand_url,
      'PRIVACY_URL' => brand_url
    }

    rename.each do |name, new_value|
      config = InstallationConfig.find_by(name: name)
      next if config.blank? || config.value.to_s.strip != 'Chatwoot'

      config.update!(value: new_value)
      puts "[omni:rebrand] #{name}: 'Chatwoot' -> '#{new_value}'"
    end

    urls.each do |name, new_value|
      config = InstallationConfig.find_by(name: name)
      next if config.blank? || !config.value.to_s.include?('chatwoot.com')

      old_value = config.value
      config.update!(value: new_value)
      puts "[omni:rebrand] #{name}: '#{old_value}' -> '#{new_value}'"
    end

    # Remove o cache de "última versão" gravado pelo hub do Chatwoot, para que
    # nenhum aviso de "atualização disponível" seja exibido (updates são manuais).
    begin
      Redis::Alfred.delete(Redis::Alfred::LATEST_CHATWOOT_VERSION)
      puts '[omni:rebrand] cache de versão limpo.'
    rescue StandardError => e
      puts "[omni:rebrand] aviso: não foi possível limpar o cache de versão (#{e.class})."
    end

    puts '[omni:rebrand] concluído.'
  end
end
