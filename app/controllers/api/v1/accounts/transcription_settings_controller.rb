class Api::V1::Accounts::TranscriptionSettingsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :fetch_setting

  def show; end

  def update
    attrs = setting_params.to_h
    # Deixar a chave em branco mantém a atual (o front nunca recebe o segredo).
    attrs = attrs.except('api_key') if attrs['api_key'].blank?
    @setting.assign_attributes(attrs)
    @setting.save!
    render :show
  end

  private

  def fetch_setting
    @account = Current.account
    @setting = @account.transcription_setting || @account.build_transcription_setting(provider: 'system')
  end

  def setting_params
    params.permit(:provider, :endpoint, :model, :language, :api_key)
  end
end
