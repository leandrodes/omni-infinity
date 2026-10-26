# frozen_string_literal: true

class TypebotConversation < ApplicationRecord
  belongs_to :conversation

  validates :session_id, presence: true
end
