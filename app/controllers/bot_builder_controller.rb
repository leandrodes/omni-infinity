# frozen_string_literal: true

class BotBuilderController < ApplicationController
  include BotBuilderAuth

  layout false
  before_action :authenticate_bot_builder_user!
  before_action :set_account
  before_action :set_workspace, only: :index

  def index
    @typebot_url = "#{ENV.fetch('TYPEBOT_PUBLIC_URL', 'https://typebot.infinitytelecom.com.br')}/typebots?workspaceId=#{@workspace.workspace_id}"
  rescue Typebot::Client::Error, PG::Error => e
    @typebot_url = nil
    @error = e.message
  end

  def documentation
    @teams = @account.teams.order(:name)
    @agents = @account.users.order(:name)
  end

  def licenses
  end

  private

  def authenticate_bot_builder_user!
    @bot_builder_user = bot_builder_user_from_cookie
    redirect_to('/app/login') and return unless @bot_builder_user
  end

  def set_account
    account_id = params[:account_id].presence ||
                 AccountUser.where(user_id: @bot_builder_user.id, role: :administrator).pick(:account_id)

    @account = Account.find_by(id: account_id)
    return if @account && AccountUser.exists?(
      user_id: @bot_builder_user.id,
      account_id: @account.id,
      role: :administrator
    )

    render plain: 'Acesso negado. Somente administradores da conta podem usar o Chatbot.', status: :forbidden
  end

  def set_workspace
    @workspace = Typebot::ProvisionWorkspaceService.new(account: @account).perform
  rescue Typebot::Client::Error, PG::Error => e
    @workspace = TypebotAccountWorkspace.find_by(account_id: @account.id)
    return if @workspace.present?

    render plain: "Chatbot indisponível: #{e.message}", status: :service_unavailable
  end
end
