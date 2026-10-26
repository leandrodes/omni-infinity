# frozen_string_literal: true

class TypebotAccountWorkspace < ApplicationRecord
  belongs_to :account

  validates :workspace_id, presence: true
end
