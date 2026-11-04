class CannedResponseInbox < ApplicationRecord
  belongs_to :canned_response, touch: true
  belongs_to :inbox

  validates :inbox_id, uniqueness: { scope: :canned_response_id }
end
