class Api::V1::Accounts::Conversations::MessagesController < Api::V1::Accounts::Conversations::BaseController
  before_action :ensure_api_inbox, only: :update
  before_action :ensure_editable_unofficial_message, only: :edit

  def index
    @messages = message_finder.perform
  end

  def edit
    correction = Messages::MessageBuilder.new(Current.user, @conversation, correction_params).perform
    render json: correction.push_event_data
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def create
    if @conversation.resolved? && (
      params[:message_type].blank? ||
      params[:message_type].to_s == 'outgoing' ||
      ActiveModel::Type::Boolean.new.cast(params[:private])
    )
      render json: { error: 'Reopen the conversation before sending a message' }, status: :unprocessable_entity
      return
    end

    user = Current.user || @resource
    mb = Messages::MessageBuilder.new(user, @conversation, params)
    @message = mb.perform
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def update
    Messages::StatusUpdateService.new(message, permitted_params[:status], permitted_params[:external_error]).perform
    @message = message
  end

  def destroy
    delete_message_remotely
    deleted_attributes = (message.content_attributes || {}).merge(
      'deleted' => true,
      'deleted_at' => Time.current.iso8601,
      'deleted_by_id' => Current.user&.id
    )
    message.update!(content_attributes: deleted_attributes)
    @message = message
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def retry
    return if message.blank?

    ::SendReplyJob.perform_later(message.id) if claim_message_retry
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def pinned
    messages = @conversation.messages.pinned.order(pinned_at: :desc)
    render json: { payload: messages.map(&:push_event_data) }
  end

  def pin
    message.update!(pinned_at: Time.current, pinned_by_id: Current.user&.id)
    render json: message.push_event_data
  end

  def unpin
    message.update!(pinned_at: nil, pinned_by_id: nil)
    render json: message.push_event_data
  end

  def translate
    return head :ok if already_translated_content_available?

    translated_content = Integrations::GoogleTranslate::ProcessorService.new(
      message: message,
      target_language: permitted_params[:target_language]
    ).perform

    if translated_content.present?
      translations = {}
      translations[permitted_params[:target_language]] = translated_content
      translations = message.translations.merge!(translations) if message.translations.present?
      message.update!(translations: translations)
    end

    render json: { content: translated_content }
  rescue Google::Cloud::Error => e
    # `details` carries the clean human message; `message` includes gRPC debug noise
    render_could_not_create_error(e.details.presence || e.message)
  end

  private

  def message
    @message ||= @conversation.messages.find(permitted_params[:id])
  end

  def correction_params
    ActionController::Parameters.new(
      content: correction_content,
      message_type: 'outgoing',
      content_attributes: {
        in_reply_to: message.id,
        message_correction: true
      }
    )
  end

  def correction_content
    content = permitted_params[:content].to_s.strip
    return content unless signature_required?

    signature = (Current.user.message_signature.presence || Current.user.name).to_s.strip
    return content if signature.blank? || content.end_with?(signature)

    [content, signature].reject(&:blank?).join("\n")
  end

  def signature_required?
    (Current.account.settings || {})['signature_agents_can_disable'] != true
  end

  def message_finder
    @message_finder ||= MessageFinder.new(@conversation, params)
  end

  def claim_message_retry
    message.with_lock do
      next false unless message.failed?

      Messages::StatusUpdateService.new(message, 'sent').perform
      previous_source_id = message.source_id
      retry_attributes = { content_attributes: retry_content_attributes }
      retry_attributes[:source_id] = nil unless @conversation.inbox.api? || @conversation.inbox.web_widget?
      message.update!(retry_attributes)
      if retry_attributes.key?(:source_id) && previous_source_id.present?
        Rails.logger.info "Cleared older source ID #{previous_source_id} for message #{message.id}"
      end
      true
    end
  end

  def delete_message_remotely
    return unless message.outgoing?
    return unless @conversation.inbox.channel_type == 'Channel::UnofficialWhatsapp'

    @conversation.inbox.channel.delete_message(message)
  end

  def retry_content_attributes
    return message.content_attributes if message.content_attributes.dig('whatsapp_contact_info', 'type') == 'request'

    {}
  end

  def permitted_params
    params.permit(:id, :target_language, :status, :external_error, :content)
  end

  def already_translated_content_available?
    message.translations.present? && message.translations[permitted_params[:target_language]].present?
  end

  def ensure_editable_unofficial_message
    return render_edit_error('Message editing is only available for WhatsApp unofficial text messages') unless unofficial_inbox?
    return render_edit_error('You can only edit your own outgoing text messages') unless own_outgoing_message?
    return render_edit_error('Only text messages without attachments can be edited', :unprocessable_entity) unless editable_text_message?

    render_edit_error('Message content is required', :unprocessable_entity) if permitted_params[:content].blank?
  end

  def unofficial_inbox? = @conversation.inbox.channel_type == 'Channel::UnofficialWhatsapp'

  def own_outgoing_message?
    message.outgoing? && message.sender_type == 'User' && message.sender_id == Current.user.id
  end

  def editable_text_message?
    message.content_type == 'text' && message.attachments.blank? && !message.private?
  end

  def render_edit_error(message, status = :forbidden)
    render json: { error: message }, status: status
  end

  # API inbox check
  def ensure_api_inbox
    # Only API inboxes can update messages
    render json: { error: 'Message status update is only allowed for API inboxes' }, status: :forbidden unless @conversation.inbox.api?
  end
end

Api::V1::Accounts::Conversations::MessagesController.prepend_mod_with('Api::V1::Accounts::Conversations::MessagesController')
