class Webhooks::UnofficialWhatsappController < ActionController::API
  def process_payload
    channel = Channel::UnofficialWhatsapp.find_by(identifier: params[:identifier])
    return head :ok if channel.blank?

    Webhooks::UnofficialWhatsappEventsJob.perform_later(
      identifier: params[:identifier],
      payload: request.request_parameters
    )
    head :ok
  end
end
