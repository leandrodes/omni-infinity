json.payload do
  json.array! @conversations do |conversation|
    json.partial! 'api/v1/conversations/partials/conversation',
                  formats: [:json],
                  conversation: conversation
    json.csat_rating conversation.csat_survey_response&.rating
  end
end
