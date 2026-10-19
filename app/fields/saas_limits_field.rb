require 'administrate/field/base'

# Community-edition replacement for the enterprise AccountLimitsField.
# Only exposes the two limits managed by Infinity: max users (agents) and
# max inboxes. Blank values mean "unlimited" (falls back to the install max).
class SaasLimitsField < Administrate::Field::Base
  def to_s
    defaults = { max_users: nil, max_inboxes: nil }
    overrides = (data.presence || {}).to_h.symbolize_keys.slice(:max_users, :max_inboxes).compact
    defaults.merge(overrides).to_json
  end
end
