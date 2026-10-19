# Configuração da transcrição de áudio por conta.
#
# `provider`:
#   - "system"   -> usa a transcrição interna (Whisper gerenciado), controlada
#                   pelo super-admin via `accounts.transcription_allow_system`.
#   - "external" -> provedor externo do próprio cliente. Aceita APIs
#                   compatíveis com OpenAI/Groq (/audio/transcriptions) e
#                   servidores Whisper (whisper-asr-webservice, /asr). O estilo
#                   é detectado pela URL informada.
class TranscriptionSetting < ApplicationRecord
  PROVIDERS = %w[system external].freeze

  belongs_to :account

  validates :provider, inclusion: { in: PROVIDERS }

  encrypts :api_key if Chatwoot.encryption_configured?
end
