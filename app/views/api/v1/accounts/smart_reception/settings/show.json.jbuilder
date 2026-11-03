json.payload do
  json.id @setting.id
  json.inbox_id @setting.inbox_id
  json.name @setting.name
  json.provider @setting.provider
  json.model @setting.model
  json.api_key_present @setting.api_key.present?
  json.temperature @setting.temperature.to_f
  json.max_response_tokens @setting.max_response_tokens
  json.max_history_messages @setting.max_history_messages
  json.use_previous_conversations @setting.use_previous_conversations
  json.min_wait_seconds @setting.min_wait_seconds
  json.max_wait_seconds @setting.max_wait_seconds
  json.primary_prompt @setting.primary_prompt
  json.secondary_prompt @setting.secondary_prompt
  json.label_id @setting.label_id
  json.team_id @setting.team_id
  json.read_help_center @setting.read_help_center
  json.enabled @setting.enabled

  json.keyword_rules @setting.keyword_rules.order(:id) do |rule|
    json.id rule.id
    json.keywords rule.keywords
    json.action rule.action
    json.team_id rule.team_id
    json.label_id rule.label_id
    json.enabled rule.enabled
  end

  json.attachments @setting.attachments.includes(file_attachment: :blob).order(:id) do |attachment|
    json.id attachment.id
    json.keywords attachment.keywords
    json.caption attachment.caption
    json.filename attachment.file.filename.to_s
    json.file_size attachment.file.byte_size
    json.file_type attachment.file.content_type
    json.data_url attachment.file_url
  end
end

json.options do
  json.providers SmartReception::ProviderCatalog.providers
  json.actions [
    { value: 'transfer', label: I18n.t('smart_reception.actions.transfer') },
    { value: 'resolve', label: I18n.t('smart_reception.actions.resolve') }
  ]
end
