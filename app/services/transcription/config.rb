# Configuração da transcrição de áudio (container Whisper), definida pelo
# super-admin em Super Admin > Configurações > Transcrição.
#
# A transcrição fica disponível sempre que um endpoint estiver configurado.
# Como o ConfigLoader pré-cria um registro em branco para estas chaves (sem
# valor padrão em installation_config.yml), usamos `presence || ENV` para que
# uma variável de ambiente ainda possa servir de fallback.
module Transcription
  module Config
    module_function

    def endpoint
      value('TRANSCRIPTION_ENDPOINT').to_s.chomp('/')
    end

    def api_key
      value('TRANSCRIPTION_API_KEY').to_s
    end

    def model
      value('TRANSCRIPTION_MODEL').presence || 'base'
    end

    def language
      value('TRANSCRIPTION_LANGUAGE').presence
    end

    # Habilita a transcrição quando há um endpoint configurado.
    def configured?
      endpoint.present?
    end

    # Permite desligar por conta via "Transcrição de Áudio" nas configurações
    # da conta (nil = ligado por padrão quando o endpoint está configurado).
    def enabled_for?(account)
      return false unless configured?
      return true if account.blank?

      setting = account.respond_to?(:audio_transcriptions) ? account.audio_transcriptions : nil
      setting.nil? ? true : ActiveModel::Type::Boolean.new.cast(setting)
    end

    def value(key)
      GlobalConfig.get(key)[key].presence || ENV.fetch(key, nil)
    end
  end
end
