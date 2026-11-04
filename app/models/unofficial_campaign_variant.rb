class UnofficialCampaignVariant < ApplicationRecord
  belongs_to :message, class_name: 'UnofficialCampaignMessage', foreign_key: :unofficial_campaign_message_id,
                       inverse_of: :variants

  has_many_attached :attachments

  validates :content, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
