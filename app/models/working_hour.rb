# == Schema Information
#
# Table name: working_hours
#
#  id             :bigint           not null, primary key
#  close_hour     :integer
#  close_minutes  :integer
#  closed_all_day :boolean          default(FALSE)
#  day_of_week    :integer          not null
#  open_all_day   :boolean          default(FALSE)
#  open_hour      :integer
#  open_minutes   :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :bigint
#  inbox_id       :bigint
#
# Indexes
#
#  index_working_hours_on_account_id  (account_id)
#  index_working_hours_on_inbox_id    (inbox_id)
#
class WorkingHour < ApplicationRecord
  belongs_to :inbox

  before_validation :ensure_open_all_day_hours
  before_save :assign_account

  validates :open_hour,     presence: true, unless: :closed_all_day?
  validates :open_minutes,  presence: true, unless: :closed_all_day?
  validates :close_hour,    presence: true, unless: :closed_all_day?
  validates :close_minutes, presence: true, unless: :closed_all_day?

  validates :open_hour,     inclusion: 0..23, unless: :closed_all_day?
  validates :close_hour,    inclusion: 0..23, unless: :closed_all_day?
  validates :open_minutes,  inclusion: 0..59, unless: :closed_all_day?
  validates :close_minutes, inclusion: 0..59, unless: :closed_all_day?

  validates :second_open_hour,     inclusion: 0..23, if: :second_period_enabled?
  validates :second_close_hour,    inclusion: 0..23, if: :second_period_enabled?
  validates :second_open_minutes,  inclusion: 0..59, if: :second_period_enabled?
  validates :second_close_minutes, inclusion: 0..59, if: :second_period_enabled?

  validate :close_after_open, unless: :closed_all_day?
  validate :second_close_after_open, if: :second_period_enabled?
  validate :open_all_day_and_closed_all_day

  def self.today
    # While getting the day of the week, consider the timezone as well. `first` would
    # return the first working hour from the list of working hours available per week.
    inbox = first.inbox
    find_by(day_of_week: Time.zone.now.in_time_zone(inbox.timezone).to_date.wday)
  end

  def open_at?(time)
    return false if closed_all_day?
    return true if open_all_day?

    in_range?(time, open_hour, open_minutes, close_hour, close_minutes) ||
      (second_period_enabled? && in_range?(time, second_open_hour, second_open_minutes, second_close_hour, second_close_minutes))
  end

  def open_now?
    inbox_time = Time.zone.now.in_time_zone(inbox.timezone)
    open_at?(inbox_time)
  end

  def closed_now?
    !open_now?
  end

  private

  def assign_account
    self.account_id = inbox.account_id
  end

  def close_after_open
    return unless open_hour.hours + open_minutes.minutes >= close_hour.hours + close_minutes.minutes

    errors.add(:close_hour, 'Closing time cannot be before opening time')
  end

  def ensure_open_all_day_hours
    return unless open_all_day?

    self.open_hour = 0
    self.open_minutes = 0
    self.close_hour = 23
    self.close_minutes = 59
    self.second_period_enabled = false
  end

  def in_range?(time, range_open_hour, range_open_minutes, range_close_hour, range_close_minutes)
    current_time = time.in_time_zone(inbox.timezone)
    open_time = current_time.change({ hour: range_open_hour, min: range_open_minutes })
    close_time = current_time.change({ hour: range_close_hour, min: range_close_minutes })
    time.between?(open_time, close_time)
  end

  def second_close_after_open
    return if second_open_hour.blank? || second_open_minutes.blank? || second_close_hour.blank? || second_close_minutes.blank?
    return if second_open_hour.hours + second_open_minutes.minutes < second_close_hour.hours + second_close_minutes.minutes

    errors.add(:second_close_hour, 'Closing time cannot be before opening time')
  end

  def open_all_day_and_closed_all_day
    return unless open_all_day? && closed_all_day?

    errors.add(:base, 'open_all_day and closed_all_day cannot be true at the same time')
  end
end
