require 'csv'
require 'roo'

class UnofficialCampaigns::ContactImporter
  PHONE_HEADERS = %w[telefone phone phone_number celular whatsapp numero número].freeze
  NAME_HEADERS = %w[nome name cliente contato].freeze
  EMAIL_HEADERS = %w[email e-mail].freeze

  pattr_initialize [:campaign!, :file!]

  # rubocop:disable Metrics/MethodLength
  def perform
    rows = parse_rows
    return 0 if rows.empty?

    imported = 0
    rows.each do |row|
      phone = value_for(row, PHONE_HEADERS)
      next if phone.blank?

      contact = find_or_create_contact(phone, value_for(row, NAME_HEADERS), value_for(row, EMAIL_HEADERS))
      next if contact.blank?

      campaign_contact = campaign.contacts.find_or_initialize_by(phone_number: contact.phone_number)
      campaign_contact.assign_attributes(
        contact: contact,
        name: contact.name,
        source: 'csv'
      )
      campaign_contact.save!
      imported += 1
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn("[UnofficialCampaign] contact import skipped: #{e.message}")
    end
    imported
  end
  # rubocop:enable Metrics/MethodLength

  private

  def parse_rows
    extension = File.extname(file.original_filename.to_s).delete('.').downcase
    extension = 'csv' if extension.blank?

    if extension == 'csv'
      content = file.read.to_s.force_encoding('UTF-8').delete_prefix("\uFEFF")
      CSV.parse(content, headers: true).map(&:to_h)
    else
      spreadsheet_rows(extension)
    end
  rescue CSV::MalformedCSVError, Roo::Error => e
    raise ArgumentError, "Não foi possível ler o arquivo: #{e.message}"
  end

  def spreadsheet_rows(extension)
    spreadsheet = Roo::Spreadsheet.open(file.tempfile.path, extension: extension)
    sheet = spreadsheet.sheet(0)
    headers = sheet.row(1).map { |value| value.to_s.strip.downcase }
    (2..sheet.last_row).map do |line|
      values = sheet.row(line)
      headers.each_with_index.to_h { |header, index| [header, values[index]] }
    end
  end

  def value_for(row, headers)
    key = row.keys.find { |header| headers.include?(header.to_s.strip.downcase) }
    row[key].to_s.strip if key
  end

  def find_or_create_contact(phone, name, email)
    normalized_phone = normalize_phone(phone)
    return if normalized_phone.length < 8

    contact = campaign.account.contacts.find_or_initialize_by(phone_number: normalized_phone)
    contact.name = name.presence || contact.name.presence || normalized_phone
    contact.email = email.presence || contact.email
    contact.save!
    contact
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn("[UnofficialCampaign] contact #{normalized_phone} invalid: #{e.message}")
    nil
  end

  def normalize_phone(phone)
    value = phone.to_s.strip
    value = "+#{value}" if value.match?(/\A\d{10,15}\z/)
    value.gsub(/[^\d+]/, '')
  end
end
