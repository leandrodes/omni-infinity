json.enabled Transcription::Config.account_enabled?(@account)
json.provider @setting.provider
json.endpoint @setting.endpoint
json.model @setting.model
json.language @setting.language
json.api_key_present @setting.api_key.present?
json.allow_system @account.transcription_allow_system
json.system_configured Transcription::Config.system_configured?
