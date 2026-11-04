class UnofficialCampaignMessage < ApplicationRecord
  belongs_to :campaign, class_name: 'UnofficialCampaign', foreign_key: :unofficial_campaign_id,
                        inverse_of: :messages
  has_many :variants, class_name: 'UnofficialCampaignVariant', dependent: :destroy, inverse_of: :message

  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :wait_min_seconds, :wait_max_seconds,
            numericality: { only_integer: true, greater_than_or_equal_to: 3, less_than_or_equal_to: 8 }
  validate :max_wait_after_min_wait

  scope :ordered, -> { order(:position, :id) }

  private

  def max_wait_after_min_wait
    return if wait_max_seconds.blank? || wait_min_seconds.blank?
    return if wait_max_seconds >= wait_min_seconds

    errors.add(:wait_max_seconds, 'deve ser maior ou igual ao tempo mínimo')
  end
end
