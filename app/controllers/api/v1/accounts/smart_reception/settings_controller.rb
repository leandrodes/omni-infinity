class Api::V1::Accounts::SmartReception::SettingsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :fetch_inbox
  before_action :ensure_feature_enabled
  before_action :fetch_setting, only: [:show, :update]

  def show; end

  def update
    if setting_params[:enabled] && @inbox.agent_bot_inbox.present?
      return render json: {
        error: I18n.t('smart_reception.errors.chatbot_enabled')
      }, status: :unprocessable_entity
    end

    ActiveRecord::Base.transaction do
      attrs = setting_params.to_h
      api_key = attrs.delete('api_key')
      @setting.assign_attributes(attrs)
      @setting.api_key = api_key if api_key.present?
      @setting.save!
      sync_keyword_rules!
    end
    render :show
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
  end

  def fetch_setting
    @setting = @inbox.smart_reception_setting || @inbox.build_smart_reception_setting(
      account: Current.account,
      **SmartReception::Setting.default_prompts
    )
  end

  def ensure_feature_enabled
    return if Current.account.feature_enabled?('saas_ai_smart_reception')

    render json: { error: I18n.t('smart_reception.errors.disabled') },
           status: :not_found
  end

  def setting_params
    params.require(:smart_reception_setting).permit(
      :name, :provider, :model, :api_key, :temperature, :max_response_tokens,
      :max_history_messages, :use_previous_conversations, :min_wait_seconds,
      :max_wait_seconds, :primary_prompt, :secondary_prompt, :label_id, :team_id,
      :read_help_center, :enabled
    )
  end

  def keyword_rules_params
    Array(params[:keyword_rules]).map do |rule|
      rule.permit(:keywords, :action, :team_id, :label_id, :enabled).to_h
    end
  end

  def sync_keyword_rules!
    return unless params.key?(:keyword_rules)

    @setting.keyword_rules.destroy_all
    keyword_rules_params.each do |rule|
      @setting.keyword_rules.create!(rule.merge(account: Current.account))
    end
  end
end
