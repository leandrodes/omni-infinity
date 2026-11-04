# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
class UnofficialCampaign < ApplicationRecord
  POST_ACTIONS = %w[assign_team assign_team_agent pending_team resolve].freeze
  START_MODES = %w[immediate scheduled].freeze

  belongs_to :account
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :post_team, class_name: 'Team', optional: true
  belongs_to :post_agent, class_name: 'User', optional: true

  has_many :messages, class_name: 'UnofficialCampaignMessage', dependent: :destroy, inverse_of: :campaign
  has_many :variants, through: :messages
  has_many :contacts, class_name: 'UnofficialCampaignContact', dependent: :destroy, inverse_of: :campaign

  enum status: { draft: 0, scheduled: 1, running: 2, completed: 3, cancelled: 4 }

  validates :title, presence: true
  validates :start_mode, inclusion: { in: START_MODES }
  validates :post_action, inclusion: { in: POST_ACTIONS }
  validates :sender_inbox_ids, presence: true
  validates :min_contact_interval_seconds, :max_contact_interval_seconds,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :max_interval_after_min_interval
  validate :scheduled_at_required_for_scheduled_mode
  validate :post_team_required_for_team_actions
  validate :sender_inboxes_belong_to_account
  validate :allowed_window

  before_validation :normalize_sender_inbox_ids

  def sender_inboxes
    account.inboxes.where(id: sender_inbox_ids)
  end

  def allowed_now?(time = Time.current)
    local = time.in_time_zone(account_timezone)
    return false unless Array(allowed_days).map(&:to_i).include?(local.wday)

    minute = (local.hour * 60) + local.min
    minute.between?(allowed_start_minute, allowed_end_minute)
  end

  def next_allowed_time(from = Time.current)
    local = from.in_time_zone(account_timezone)
    days = Array(allowed_days).map(&:to_i).presence || (0..6).to_a

    0.upto(7) do |offset|
      date = local.to_date + offset.days
      next unless days.include?(date.wday)

      candidate = date.in_time_zone(account_timezone).change(
        hour: allowed_start_minute / 60,
        min: allowed_start_minute % 60,
        sec: 0
      )
      next if candidate < local

      return candidate
    end

    from + 1.day
  end

  def account_timezone
    account.custom_attributes&.dig('timezone').presence || Time.zone.name
  end

  def random_between(min, max)
    min = min.to_i
    max = max.to_i
    max = min if max < min
    rand(min..max)
  end

  def next_contact_delay
    delay = random_between(min_contact_interval_seconds, max_contact_interval_seconds)
    if pause_enabled? && next_pause_count.positive? && contacts.sent.count >= next_pause_count
      delay += random_between(pause_min_minutes, pause_max_minutes).minutes.to_i
      update!(next_pause_count: contacts.sent.count + random_between(pause_every_min_contacts, pause_every_max_contacts))
    end
    delay
  end

  def next_sender_inbox
    inboxes = sender_inboxes.to_a
    return if inboxes.empty?

    inbox = inboxes[next_sender_index % inboxes.length]
    update!(next_sender_index: next_sender_index + 1)
    inbox
  end

  def mark_completed_if_done!
    return if contacts.pending.exists? || contacts.processing.exists?

    update!(status: :completed, completed_at: Time.current)
  end

  def start!
    return unless scheduled? || draft?

    if start_mode == 'scheduled' && scheduled_at.present? && scheduled_at > Time.current
      update!(status: :scheduled)
      return
    end

    update!(status: :running, started_at: Time.current)
    update!(next_pause_count: contacts.sent.count + random_between(pause_every_min_contacts, pause_every_max_contacts)) if pause_enabled?
    UnofficialCampaigns::ContactJob.set(wait: 1.second).perform_later(id, contacts.pending.order(:id).first&.id)
  end

  private

  def normalize_sender_inbox_ids
    self.sender_inbox_ids = Array(sender_inbox_ids).compact_blank.map(&:to_i).uniq
  end

  def max_interval_after_min_interval
    return if max_contact_interval_seconds.blank? || min_contact_interval_seconds.blank?
    return if max_contact_interval_seconds >= min_contact_interval_seconds

    errors.add(:max_contact_interval_seconds, 'deve ser maior ou igual ao intervalo mínimo')
  end

  def scheduled_at_required_for_scheduled_mode
    return unless start_mode == 'scheduled' && scheduled_at.blank?

    errors.add(:scheduled_at, 'é obrigatório quando a campanha é programada')
  end

  def post_team_required_for_team_actions
    return if post_action == 'resolve'
    return if post_team_id.present?

    errors.add(:post_team_id, 'é obrigatório para esta ação')
  end

  def sender_inboxes_belong_to_account
    return if account.blank?

    ids = Array(sender_inbox_ids).map(&:to_i)
    return if ids.empty? || account.inboxes.where(id: ids).count == ids.size

    errors.add(:sender_inbox_ids, 'contém caixas de entrada inválidas')
  end

  def allowed_window
    return if allowed_start_minute.blank? || allowed_end_minute.blank?
    return if allowed_start_minute < allowed_end_minute

    errors.add(:allowed_end_minute, 'deve ser maior que o horário inicial')
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity
