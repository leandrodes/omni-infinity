json.array! @team_members do |team_member|
  json.partial! 'api/v1/models/agent', formats: [:json], resource: team_member.user
  json.priority_level team_member.priority_level
end
