class Api::V1::Accounts::UnofficialWhatsapp::InstancesController < Api::V1::Accounts::BaseController
  before_action :fetch_inbox
  before_action :ensure_channel!

  # Provisions a remote session for this inbox and starts the WhatsApp pairing.
  # The first call creates the remote session; subsequent calls just reconnect.
  def create
    channel = @inbox.channel

    provision(channel) unless channel.provider_service.provisioned?

    provider = channel.provider_service
    provider.connect
    channel.update!(connection_status: 'connecting')

    render json: status_payload(channel)
  rescue UnofficialWhatsapp::Providers::WuzapiService::WuzapiError,
         UnofficialWhatsapp::Providers::EvolutionService::EvolutionError => e
    render json: { message: e.message }, status: :unprocessable_entity
  end

  def qrcode
    channel = @inbox.channel
    service = channel.provider_service
    response = service.qrcode

    if response.success?
      render json: { qr_code: service.qrcode_from(response) }
    else
      render json: { message: response.body.to_s.first(255) }, status: :unprocessable_entity
    end
  end

  def status
    channel = @inbox.channel
    service = channel.provider_service
    response = service.status

    if response.success?
      parsed = service.parse_status(response)
      new_status = compute_status(channel, parsed[:logged_in], parsed[:connected])
      channel.update!(connection_status: new_status) if channel.connection_status != new_status

      render json: status_payload(channel).merge(connected: parsed[:connected], logged_in: parsed[:logged_in])
    else
      render json: { message: response.body.to_s.first(255) }, status: :unprocessable_entity
    end
  end

  def logout
    channel = @inbox.channel
    service = channel.provider_service
    remote_id = remote_id_for(channel, service)

    service.logout
    # Tear down the remote session so a fresh QR scan is required next time.
    service.delete_session(remote_id) if remote_id.present?
    channel.update!(
      connection_status: 'disconnected',
      instance_token: nil,
      provider_config: channel.provider_config.except(service.remote_id_key)
    )

    render json: status_payload(channel)
  end

  # Switches the API provider of an existing inbox without recreating it.
  # The current remote session is torn down and the client must scan a new QR.
  def update_provider
    channel = @inbox.channel
    new_provider = params[:provider].to_s

    unless Channel::UnofficialWhatsapp::PROVIDERS.include?(new_provider)
      return render json: { message: 'Provedor inválido.' }, status: :unprocessable_entity
    end

    return render json: status_payload(channel) if channel.provider == new_provider

    unless Current.account.feature_enabled?("saas_channel_#{new_provider}")
      return render json: { message: I18n.t('errors.inboxes.unofficial_whatsapp.provider_not_enabled') },
                    status: :unprocessable_entity
    end

    teardown_session(channel)
    channel.update!(
      provider: new_provider,
      connection_status: 'initial',
      instance_token: nil,
      provider_config: channel.provider_config.except('wuzapi_user_id', 'evolution_instance')
    )

    render json: status_payload(channel)
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  private

  def provision(channel)
    service = channel.provider_service
    remote = service.create_session(
      name: "omni-#{channel.account_id}-inbox-#{@inbox.id}",
      webhook: @inbox.callback_webhook_url
    )
    channel.update!(
      instance_token: remote[:token],
      provider_config: channel.provider_config.merge(service.remote_id_key => remote[:id])
    )
  end

  def teardown_session(channel)
    service = channel.provider_service
    remote_id = remote_id_for(channel, service)
    service.logout
    service.delete_session(remote_id) if remote_id.present?
  rescue StandardError => e
    Rails.logger.warn("UnofficialWhatsapp teardown failed: #{e.class}: #{e.message}")
  end

  def remote_id_for(channel, service)
    channel.provider_config[service.remote_id_key]
  rescue StandardError
    nil
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
