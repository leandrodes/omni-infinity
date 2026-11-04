class UnofficialCampaigns::StartJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform(campaign_id)
    campaign = UnofficialCampaign.find_by(id: campaign_id)
    return unless campaign
    return unless campaign.draft? || campaign.scheduled?

    campaign.start!
  end
end
