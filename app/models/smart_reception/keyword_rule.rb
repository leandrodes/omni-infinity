class SmartReception::KeywordRule < ApplicationRecord
  self.table_name = 'smart_reception_keyword_rules'

  ACTIONS = %w[transfer resolve].freeze

  belongs_to :account
  belongs_to :setting, class_name: 'SmartReception::Setting',
                       foreign_key: :smart_reception_setting_id,
                       inverse_of: :keyword_rules
  belongs_to :team, optional: true
  belongs_to :label, optional: true

  validates :keywords, presence: true
  validates :action, inclusion: { in: ACTIONS }
  validate :transfer_requires_team

  scope :enabled, -> { where(enabled: true) }

  def keyword_list
    keywords.to_s.split(',').map(&:strip).map(&:downcase).reject(&:blank?)
  end

  def matches?(content)
    normalized = content.to_s.downcase
    keyword_list.any? { |keyword| normalized.include?(keyword) }
  end

  private

  def transfer_requires_team
    return unless action == 'transfer' && team_id.blank?

    errors.add(:team_id, 'é obrigatório para transferir')
  end
end
