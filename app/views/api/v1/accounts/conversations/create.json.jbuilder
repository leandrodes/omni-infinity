json.partial! 'api/v1/conversations/partials/conversation', formats: [:json], conversation: @conversation
json.existing_conversation @existing_whatsapp_conversation.present?
