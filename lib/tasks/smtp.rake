require 'net/smtp'
require 'resolv'
require 'openssl'

# rubocop:disable Metrics/BlockLength, Rails/I18nLocaleTexts
namespace :smtp do
  desc 'Validate SMTP connection and authentication without sending an email'
  task check: :environment do
    settings = ActionMailer::Base.smtp_settings
    address = settings[:address].to_s
    port = settings[:port].to_i
    domain = settings[:domain].presence || ENV.fetch('FRONTEND_URL', 'localhost')
    user_name = settings[:user_name].to_s
    password = settings[:password].to_s
    authentication = settings[:authentication].presence || :login
    starttls = ActiveModel::Type::Boolean.new.cast(settings[:enable_starttls_auto])
    ssl = ActiveModel::Type::Boolean.new.cast(settings[:ssl])
    verify_tls = settings[:openssl_verify_mode].to_s != 'none'

    puts "smtp_address=#{address}"
    puts "smtp_port=#{port}"
    puts "smtp_user=#{user_name.presence || '(none)'}"
    puts "smtp_auth=#{authentication}"
    puts "smtp_starttls=#{starttls}"
    puts "smtp_ssl=#{ssl}"
    puts "smtp_tls_verify=#{verify_tls}"
    puts "mailer_sender=#{ENV.fetch('MAILER_SENDER_EMAIL', '(none)')}"

    abort 'SMTP_ADDRESS is empty' if address.blank?
    abort 'SMTP_ADDRESS still contains the placeholder seudominio' if address.include?('seudominio')
    abort 'SMTP_USERNAME is empty' if user_name.blank?
    abort 'SMTP_PASSWORD is empty' if password.blank?

    addresses = Resolv.getaddresses(address)
    abort "DNS did not resolve #{address}" if addresses.empty?

    puts "dns_addresses=#{addresses.join(',')}"

    smtp = Net::SMTP.new(address, port)
    smtp.open_timeout = ENV.fetch('SMTP_OPEN_TIMEOUT', 15).to_i
    smtp.read_timeout = ENV.fetch('SMTP_READ_TIMEOUT', 30).to_i

    if ssl
      smtp.enable_tls
    elsif starttls
      smtp.enable_starttls_auto
    end

    smtp.tls_verify = verify_tls if smtp.respond_to?(:tls_verify=)
    smtp.start(domain, user_name, password, authentication.to_sym)
    smtp.finish

    puts 'SMTP_CHECK=PASS'
  rescue StandardError => e
    puts "SMTP_CHECK=FAIL #{e.class}: #{e.message}"
    exit 1
  end

  desc 'Send a test email using the configured SMTP settings'
  task :test, [:to] => :environment do |_task, args|
    to = args[:to].to_s
    abort 'Usage: rails smtp:test[destinatario@dominio.com]' if to.blank?

    from = ENV.fetch('MAILER_SENDER_EMAIL', nil)
    abort 'MAILER_SENDER_EMAIL is empty' if from.blank?

    ActionMailer::Base.mail(
      from: from,
      to: to,
      subject: 'Teste SMTP Chatwoot',
      body: "SMTP configurado com sucesso em #{Time.current.iso8601}"
    ).deliver_now

    puts "SMTP_TEST=PASS to=#{to}"
  rescue StandardError => e
    puts "SMTP_TEST=FAIL #{e.class}: #{e.message}"
    exit 1
  end
end
# rubocop:enable Metrics/BlockLength, Rails/I18nLocaleTexts
