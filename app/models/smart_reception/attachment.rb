class SmartReception::Attachment < ApplicationRecord
  self.table_name = 'smart_reception_attachments'

  belongs_to :account
  belongs_to :setting, class_name: 'SmartReception::Setting',
                       foreign_key: :smart_reception_setting_id,
                       inverse_of: :attachments

  has_one_attached :file, dependent: :purge_later

  validates :file, presence: true
  validates :keywords, presence: true
  validate :acceptable_file

  def keyword_list
    keywords.to_s.split(',').map(&:strip).map(&:downcase).reject(&:blank?)
  end

  def matches?(content)
    normalized = content.to_s.downcase
    keyword_list.any? { |keyword| normalized.include?(keyword) }
  end

  def file_url
    file.attached? ? Rails.application.routes.url_helpers.url_for(file) : ''
  end

  private

  def acceptable_file
    return unless file.attached?

    if dangerous_extension? || ContactAttachment::BLOCKED_CONTENT_TYPES.include?(file.content_type.to_s.downcase)
      errors.add(:file, 'type is not allowed')
    elsif file.byte_size > max_file_size
      errors.add(:file, "must be smaller than #{max_file_size_mb} MB")
    end
  end

  def dangerous_extension?
    file.filename.to_s.downcase.split('.').drop(1).intersect?(ContactAttachment::BLOCKED_EXTENSIONS)
  end

  def max_file_size
    max_file_size_mb.megabytes
  end

  def max_file_size_mb
    GlobalConfigService.load('MAXIMUM_FILE_UPLOAD_SIZE', ContactAttachment::DEFAULT_MAX_FILE_SIZE_MB).to_i
  end
end
