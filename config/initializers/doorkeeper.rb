# frozen_string_literal: true

Doorkeeper.configure do
  orm :active_record

  # The Typebot builder is opened inside Chatwoot. The browser already has the
  # token-based Chatwoot session in the `cw_d_session_info` cookie, so use that
  # as the source of truth instead of relying on a server-side login session.
  resource_owner_authenticator do
    payload = begin
      JSON.parse(cookies[:cw_d_session_info].to_s)
    rescue JSON::ParserError
      nil
    end

    user = nil
    if payload.present?
      uid = payload['uid'].to_s
      token = payload['access-token'].to_s
      client = payload['client'].to_s

      if uid.present? && token.present? && client.present?
        candidate = User.find_by(uid: uid) || User.find_by(email: uid)
        user = candidate if candidate&.valid_token?(token, client)
      end
    end

    if user && AccountUser.where(user_id: user.id, role: :administrator).exists?
      user
    else
      redirect_to('/app/login')
    end
  end

  default_scopes :openid
  optional_scopes :email, :profile

  grant_flows %w[authorization_code]

  # Typebot is our own trusted client. Skip the consent screen for it, but keep
  # consent for any other application that may be registered in the future.
  skip_authorization do |_resource_owner, application|
    ENV['TYPEBOT_OIDC_CLIENT_ID'].present? &&
      application.uid == ENV['TYPEBOT_OIDC_CLIENT_ID']
  end

  access_token_expires_in 2.hours
  authorization_code_expires_in 10.minutes
  use_refresh_token

end
