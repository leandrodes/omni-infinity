# frozen_string_literal: true

signing_key_path = ENV.fetch(
  'OIDC_SIGNING_KEY_PATH',
  Rails.root.join('config', 'oidc_signing_key.pem').to_s
)

signing_key =
  if ENV['OIDC_SIGNING_KEY'].present?
    ENV['OIDC_SIGNING_KEY']
  elsif File.exist?(signing_key_path)
    File.read(signing_key_path)
  else
    Rails.logger.warn("[OIDC] Signing key not found at #{signing_key_path}; generating an ephemeral key")
    OpenSSL::PKey::RSA.generate(2048).to_pem
  end

Doorkeeper::OpenidConnect.configure do
  issuer do |_resource_owner, _application, _request|
    ENV.fetch('OIDC_ISSUER', 'https://omnichannel.infinitytelecom.com.br')
  end

  signing_key signing_key

  subject_types_supported [:public]

  resource_owner_from_access_token do |access_token|
    User.find_by(id: access_token.resource_owner_id)
  end

  auth_time_from_resource_owner do |resource_owner|
    resource_owner.current_sign_in_at || Time.current
  end

  reauthenticate_resource_owner do |_resource_owner, _return_to|
    redirect_to('/app/login')
  end

  select_account_for_resource_owner do |_resource_owner, _return_to|
    redirect_to('/app/login')
  end

  subject do |resource_owner, _application|
    resource_owner.id.to_s
  end

  claims do
    normal_claim :email, scope: :email, response: %i[id_token user_info] do |resource_owner|
      resource_owner.email
    end

    normal_claim :name, scope: :profile, response: %i[id_token user_info] do |resource_owner|
      resource_owner.available_name.presence || resource_owner.name
    end

    normal_claim :picture, scope: :profile, response: %i[user_info] do |resource_owner|
      avatar = resource_owner.avatar_url
      next if avatar.blank?

      avatar.start_with?('http') ? avatar : "#{ENV.fetch('FRONTEND_URL', 'https://omnichannel.infinitytelecom.com.br')}#{avatar}"
    end
  end
end
