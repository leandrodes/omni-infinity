# frozen_string_literal: true

class TypebotInboxConfig < ApplicationRecord
  belongs_to :account
  belongs_to :inbox

  scope :active, -> { where(active: true) }

  validates :workspace_id, :typebot_id, presence: true
end
