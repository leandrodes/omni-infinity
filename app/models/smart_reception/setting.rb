class SmartReception::Setting < ApplicationRecord
  self.table_name = 'smart_reception_settings'

  DEFAULT_PRIMARY_PROMPT = <<~PROMPT.squish
    Você é um assistente virtual especializado em atendimento ao cliente.
    Seja sempre educado e prestativo. Somente responda o que estiver neste
    prompt e transfira para o setor responsável conforme as palavras-chave.
  PROMPT

  DEFAULT_SECONDARY_PROMPT = <<~PROMPT.squish
    Responda de forma clara e objetiva. Se não souber algo, seja honesto
    sobre isso.
  PROMPT

  belongs_to :account
  belongs_to :inbox
  belongs_to :team, optional: true
  belongs_to :label, optional: true

  has_many :keyword_rules, class_name: 'SmartReception::KeywordRule',
                           dependent: :destroy,
                           inverse_of: :setting
  has_many :attachments, class_name: 'SmartReception::Attachment',
                         dependent: :destroy,
                         inverse_of: :setting

  encrypts :api_key if Chatwoot.encryption_configured?

  before_validation :apply_prompt_defaults

  validates :provider, inclusion: { in: SmartReception::ProviderCatalog::PROVIDERS.keys }
  validates :model, presence: true
  validates :temperature, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :max_response_tokens, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 8000 }
  validates :max_history_messages, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100 }
  validates :min_wait_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 300 }
  validates :max_wait_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 600 }
  validates :api_key, presence: true, if: :enabled?
  validate :provider_and_model_supported
  validate :max_wait_after_min_wait
  validate :inbox_account_matches

  def self.default_prompts
    {
      primary_prompt: DEFAULT_PRIMARY_PROMPT,
      secondary_prompt: DEFAULT_SECONDARY_PROMPT
    }
  end

  def api_key_configured?
    api_key.present?
  end

  def system_prompt
    [primary_prompt.presence || DEFAULT_PRIMARY_PROMPT,
     secondary_prompt.presence || DEFAULT_SECONDARY_PROMPT].join("\n\n")
  end

  def keyword_list
    keyword_rules.enabled.flat_map(&:keyword_list).uniq
  end

  private

  def apply_prompt_defaults
    self.primary_prompt = DEFAULT_PRIMARY_PROMPT if primary_prompt.blank?
    self.secondary_prompt = DEFAULT_SECONDARY_PROMPT if secondary_prompt.blank?
  end

  def provider_and_model_supported
    return errors.add(:provider, 'não está disponível') if SmartReception::ProviderCatalog.fetch(provider)&.dig(:coming_soon)
    return errors.add(:model, 'não é suportado por este provedor') unless SmartReception::ProviderCatalog.supported?(provider, model)

    errors.add(:provider, 'não é suportado') unless SmartReception::ProviderCatalog.fetch(provider)
  end

  def max_wait_after_min_wait
    return if max_wait_seconds.blank? || min_wait_seconds.blank?
    return if max_wait_seconds >= min_wait_seconds

    errors.add(:max_wait_seconds, 'deve ser maior ou igual ao tempo mínimo')
  end

  def inbox_account_matches
    return if inbox.blank? || account.blank?
    return if inbox.account_id == account_id

    errors.add(:inbox, 'deve pertencer à mesma conta')
  end
end
