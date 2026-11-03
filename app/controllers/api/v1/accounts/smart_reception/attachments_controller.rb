class Api::V1::Accounts::SmartReception::AttachmentsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :fetch_inbox
  before_action :ensure_feature_enabled
  before_action :fetch_setting
  before_action :fetch_attachment, only: [:destroy]

  def create
    @attachment = @setting.attachments.create!(
      account: Current.account,
      keywords: params[:keywords],
      caption: params[:caption],
      file: params[:file]
    )
    render :create
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def destroy
    @attachment.destroy!
    head :ok
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
  end

  def ensure_feature_enabled
    return if Current.account.feature_enabled?('saas_ai_smart_reception')

    render json: { error: I18n.t('smart_reception.errors.disabled') },
           status: :not_found
  end

  def fetch_setting
    @setting = @inbox.smart_reception_setting
    return if @setting.present?

    render json: { error: I18n.t('smart_reception.errors.setting_missing') }, status: :unprocessable_entity
  end

  def fetch_attachment
    @attachment = @setting.attachments.find(params[:id])
  end
end
