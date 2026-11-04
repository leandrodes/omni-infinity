class CampaignOptOutKeyword < ApplicationRecord
  belongs_to :account

  before_validation :normalize_word

  validates :word, presence: true, uniqueness: { scope: :account_id }

  DEFAULT_WORDS = %w[parar sair cancelar].freeze

  def self.words_for(account)
    account.campaign_opt_out_keywords.order(:word).pluck(:word).presence || DEFAULT_WORDS
  end

  private

  def normalize_word
    self.word = word.to_s.strip.downcase
  end
end
