json.id resource.id
json.name resource.name
json.description resource.description
json.allow_auto_assign resource.allow_auto_assign
json.auto_assignment_algorithm resource.auto_assignment_algorithm
json.icon resource.icon
json.icon_color resource.icon_color
json.account_id resource.account_id
json.is_member Current.user.is_a?(User) && Current.user.teams.include?(resource)
