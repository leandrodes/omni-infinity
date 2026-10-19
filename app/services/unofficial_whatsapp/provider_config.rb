# Central place to know whether an unofficial provider (WuzAPI / UazAPI /
# Evolution API / WaCalls) has been configured by the super-admin through the
# Installation Config screen.
#
# The "WhatsApp Não Oficial" and "Chamadas do WhatsApp (Não Oficial)" inbox
# types are only offered once the super-admin fills in the corresponding
# endpoint and token. This is intentionally based on the super-admin config
# (InstallationConfig) and NOT on environment variables, so the operator has a
# single, explicit place to enable these optional modules.
module UnofficialWhatsapp
  module ProviderConfig
    module_function

    def wuzapi_configured?
      configured?('WUZAPI_ENDPOINT', 'WUZAPI_ADMIN_TOKEN')
    end

    def uazapi_configured?
      configured?('UAZAPI_ENDPOINT', 'UAZAPI_ADMIN_TOKEN')
    end

    def evolution_configured?
      configured?('EVOLUTION_ENDPOINT', 'EVOLUTION_API_KEY')
    end

    def wacalls_configured?
      configured?('WACALLS_ENDPOINT', 'WACALLS_API_KEY')
    end

    # Whether any unofficial WhatsApp provider has been configured by the
    # super-admin. The unofficial WhatsApp inbox type is only offered when this
    # returns true.
    def any_whatsapp_provider_configured?
      wuzapi_configured? || uazapi_configured? || evolution_configured?
    end

    # Reads the value the super-admin saved. Blank values are treated as unset.
    def value(key)
      GlobalConfig.get(key)[key].to_s.strip
    end

    def configured?(*keys)
      keys.all? { |key| value(key).present? }
    end
  end
end
