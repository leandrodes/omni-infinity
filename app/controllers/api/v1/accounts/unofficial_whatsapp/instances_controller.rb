class Api::V1::Accounts::UnofficialWhatsapp::InstancesController < Api::V1::Accounts::BaseController
  before_action :fetch_inbox
  before_action :ensure_channel!

  # Provisions a WuzAPI user for this inbox and starts a WhatsApp session.
  # The first call creates the remote session; subsequent calls just reconnect.
  def create
    channel = @inbox.channel

    if channel.instance_token.blank?
      provision(channel)
    end

    provider = channel.provider_service
    provider.connect(events: 'Message')
    channel.update!(connection_status: 'connecting')

    render json: status_payload(channel)
  rescue UnofficialWhatsapp::Providers::WuzapiService::WuzapiError => e
    render json: { message: e.message }, status: :unprocessable_entity
  end

  def qrcode
    response = @inbox.channel.provider_service.qrcode
    data = response.parsed_response['data'] || {}

    if response.success?
      render json: { qr_code: data['QRCode'] }
    else
      render json: { message: response.body.to_s.first(255) }, status: :unprocessable_entity
    end
  end

  def status
    channel = @inbox.channel
    response = channel.provider_service.status
    data = response.parsed_response['data'] || {}

    if response.success?
      logged_in = truthy?(data['loggedIn'])
      connected = truthy?(data['connected'])
      new_status = compute_status(channel, logged_in, connected)
      channel.update!(connection_status: new_status) if channel.connection_status != new_status

      render json: status_payload(channel).merge(connected: connected, logged_in: logged_in)
    else
      render json: { message: response.body.to_s.first(255) }, status: :unprocessable_entity
    end
  end

  def logout
    channel = @inbox.channel
    remote_id = channel.provider_config['wuzapi_user_id']

    channel.provider_service.logout
    # Tear down the remote session so a fresh QR scan is required next time.
    channel.provider_service.delete_session(remote_id) if remote_id.present?
    channel.update!(connection_status: 'disconnected', instance_token: nil)

    render json: status_payload(channel)
  end

  private

  def provision(channel)
    service = channel.provider_service
    remote = service.create_session(
      name: "omni-#{channel.account_id}-inbox-#{@inbox.id}",
      webhook: @inbox.callback_webhook_url,
      events: 'Message'
    )
    channel.update!(
      instance_token: remote[:token],
      provider_config: channel.provider_config.merge('wuzapi_user_id' => remote[:id])
    )
  end

  def status_payload(channel)
    {
      id: @inbox.id,
      name: @inbox.name,
      connection_status: channel.connection_status,
      provider: channel.provider
    }
  end

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
    authorize @inbox, :update?
  end

  def ensure_channel!
    raise ActiveRecord::RecordNotFound unless @inbox.channel.is_a?(Channel::UnofficialWhatsapp)
  end

  def truthy?(value)
    value == true || value.to_s == 'true'
  end

  # WuzAPI reports `connected` once the socket is up, even before the phone is
  # paired. Only `loggedIn` means the WhatsApp account is actually linked, so
  # that is what maps to our 'connected' status.
  def compute_status(channel, logged_in, connected)
    return 'connected' if logged_in
    return 'connecting' if connected
    return 'disconnected' if channel.connection_status == 'connected'

    channel.connection_status
  end
end
