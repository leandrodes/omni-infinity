json.payload do
  json.array! @agents do |agent|
    json.partial! 'api/v1/models/agent', formats: [:json], resource: agent
    json.priority_level @inbox.inbox_members.find_by(user_id: agent.id)&.priority_level || 1
  end
end
