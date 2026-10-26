# frozen_string_literal: true

module BotBuilderAuth
  extend ActiveSupport::Concern

  private

  def bot_builder_user_from_cookie
    payload = JSON.parse(cookies[:cw_d_session_info].to_s)
    uid = payload['uid'].to_s
    token = payload['access-token'].to_s
    client = payload['client'].to_s

    return if uid.blank? || token.blank? || client.blank?

    user = User.find_by(uid: uid) || User.find_by(email: uid)
    user if user&.valid_token?(token, client)
  rescue JSON::ParserError
    nil
  end
end
