class ContactAttachment < ApplicationRecord
  include Rails.application.routes.url_helpers

  BLOCKED_EXTENSIONS = %w[
    apk app bash bat cmd com cpl exe hta jar js jse msi php pl ps1 py rb scr sh
    vbe vbs ws wsf wsh zsh
  ].freeze

  BLOCKED_CONTENT_TYPES = %w[
    application/x-bat
    application/x-dosexec
    application/x-executable
    application/x-msdownload
    application/x-msdos-program
    application/x-msi
    application/x-sh
    application/x-shellscript
    application/vnd.microsoft.portable-executable
  ].freeze

  DEFAULT_MAX_FILE_SIZE_MB = 40

  belongs_to :account
  belongs_to :contact
  has_one_attached :file, dependent: :purge_later

  before_validation :set_account

  validates :file, presence: true
  validate :acceptable_file

  def file_url
    file.attached? ? url_for(file) : ''
  end

  def thumb_url
    image? ? file_url : ''
  end

  def extension
    file.attached? ? file.filename.extension.to_s.downcase : ''
  end

  def image?
    file.attached? && file.content_type.to_s.start_with?('image/')
  end

  private

  def set_account
    self.account ||= contact&.account
  end

  def acceptable_file
    return unless file.attached?

    if dangerous_extension? || BLOCKED_CONTENT_TYPES.include?(file.content_type.to_s.downcase)
      errors.add(:file, 'type is not allowed')
    elsif file.byte_size > max_file_size
      errors.add(:file, "must be smaller than #{max_file_size_mb} MB")
    end
  end

  def dangerous_extension?
    file.filename.to_s.downcase.split('.').drop(1).intersect?(BLOCKED_EXTENSIONS)
  end

  def max_file_size
    max_file_size_mb.megabytes
  end

  def max_file_size_mb
    GlobalConfigService.load('MAXIMUM_FILE_UPLOAD_SIZE', DEFAULT_MAX_FILE_SIZE_MB).to_i
  end
end
