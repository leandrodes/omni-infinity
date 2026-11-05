class CannedResponseTeam < ApplicationRecord
  belongs_to :canned_response, touch: true
  belongs_to :team

  validates :team_id, uniqueness: { scope: :canned_response_id }
end
