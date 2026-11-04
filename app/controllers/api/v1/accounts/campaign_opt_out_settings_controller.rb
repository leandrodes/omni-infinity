class Api::V1::Accounts::CampaignOptOutSettingsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  def show
    render json: { words: campaign_words }
  end

  def update
    words = Array(params[:words]).map { |word| word.to_s.strip.downcase }.compact_blank.uniq
    ActiveRecord::Base.transaction do
      Current.account.campaign_opt_out_keywords.destroy_all
      words.each { |word| Current.account.campaign_opt_out_keywords.create!(word: word) }
    end
    render json: { words: campaign_words }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  private

  def campaign_words
    stored = Current.account.campaign_opt_out_keywords.order(:word).pluck(:word)
    stored.presence || CampaignOptOutKeyword::DEFAULT_WORDS
  end
end
