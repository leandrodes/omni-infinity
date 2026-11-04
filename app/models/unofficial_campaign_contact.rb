class UnofficialCampaignContact < ApplicationRecord
  belongs_to :campaign, class_name: 'UnofficialCampaign', foreign_key: :unofficial_campaign_id,
                        inverse_of: :contacts
  belongs_to :contact, optional: true
  belongs_to :sender_inbox, class_name: 'Inbox', optional: true

  enum status: { pending: 0, processing: 1, sent: 2, failed: 3, skipped: 4, opted_out: 5 }

  validates :phone_number, presence: true
  validates :phone_number, uniqueness: { scope: :unofficial_campaign_id }

  before_validation :normalize_phone_number

  scope :ready, -> { pending.where(next_send_at: ..Time.current) }

  def opted_out?
    contact&.campaign_opt_out? && source != 'csv'
  end

  def skip!(reason = nil)
    update!(status: :skipped, last_error: reason)
  end

  def mark_opted_out!
    update!(status: :opted_out, last_error: 'Contato optou por não receber campanhas')
  end

  def phone_jid
    phone_number.to_s.delete('+')
  end

  private

  def normalize_phone_number
    self.phone_number = phone_number.to_s.gsub(/[^\d+]/, '')
  end
end
