# Configuração da transcrição de áudio.
#
# Há duas camadas:
#   1. Interna ("sistema"), definida pelo super-admin em Super Admin >
#      Configurações > Transcrição. Fica disponível apenas para contas liberadas
#      (`accounts.transcription_allow_system`), o que permite cobrar pelo uso.
#   2. Por conta ("external"), definida pelo administrador da conta em
#      Configurações > Conta, usando uma API própria (OpenAI-compatível, ex.:
#      Groq) ou um servidor Whisper próprio.
#
# A transcrição só roda quando a conta a habilita E existe um provedor efetivo.
module Transcription
  module Config
    module_function

    # Estilos efetivos de requisição: :whisper_asr (whisper-asr-webservice) e
    # :openai (compatível com OpenAI/Groq).
    WHISPER_ASR = :whisper_asr
    OPENAI = :openai

    # ---- Configuração interna, definida pelo super-admin ----
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

    # Habilita a transcrição interna quando há um endpoint configurado.
    def system_configured?
      endpoint.present?
    end

    # ---- Resolução por conta ----
    def account_enabled?(account)
      return false if account.blank?

      settings = account.respond_to?(:settings) ? account.settings : nil
      return false unless settings.is_a?(Hash) || settings.respond_to?(:[])

      ActiveModel::Type::Boolean.new.cast(settings['audio_transcriptions']) == true
    end

    # Retorna um hash com os dados do provedor efetivo da conta, ou nil.
    def provider_for(account)
      return nil if account.blank?
      return nil unless account_enabled?(account)

      own = account.respond_to?(:transcription_setting) ? account.transcription_setting : nil
      if own.present? && own.provider != 'system' && own.endpoint.present?
        return {
          kind: kind_for(own.endpoint),
          endpoint: own.endpoint.to_s.chomp('/'),
          api_key: own.api_key.to_s,
          model: own.model.presence,
          language: own.language.presence
        }
      end

      return nil unless account.respond_to?(:transcription_allow_system) && account.transcription_allow_system
      return nil unless system_configured?

      {
        kind: WHISPER_ASR,
        endpoint: endpoint,
        api_key: api_key,
        model: model,
        language: language
      }
    end

    # Permite desligar por conta via "Transcrição de Áudio" nas configurações da
    # conta. A conta precisa estar explicitamente habilitada.
    def enabled_for?(account)
      provider_for(account).present?
    end

    # A transcrição só roda se estiver ligada na conta (controle global) e na
    # caixa de entrada ("Transcrever áudios recebidos"). Caixas sem a coluna
    # (instalações antigas) permanecem ligadas por padrão.
    def enabled_for_inbox?(inbox)
      return false if inbox.blank?
      return false unless enabled_for?(inbox.account)
      return true unless inbox.respond_to?(:transcribe_audio)

      ActiveModel::Type::Boolean.new.cast(inbox.transcribe_audio) != false
    end

    # Detecta o estilo do provedor externo pela URL informada.
    def kind_for(endpoint)
      endpoint.to_s.chomp('/').include?('/asr') ? WHISPER_ASR : OPENAI
    end

    def value(key)
      GlobalConfig.get(key)[key].presence || ENV.fetch(key, nil)
    end
  end
end
