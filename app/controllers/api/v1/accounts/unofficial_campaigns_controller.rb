require 'csv'

# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
class Api::V1::Accounts::UnofficialCampaignsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :fetch_campaign, only: [:show, :destroy, :start]
  before_action :ensure_feature_enabled

  def index
    campaigns = Current.account.unofficial_campaigns.order(created_at: :desc)
    render json: { payload: campaigns.map { |campaign| serialize(campaign) } }
  end

  def show
    render json: { payload: serialize(@campaign) }
  end

  def create
    campaign = Current.account.unofficial_campaigns.new(campaign_params)
    campaign.created_by = Current.user

    ActiveRecord::Base.transaction do
      campaign.save!
      create_messages!(campaign)
      add_selected_contacts!(campaign)
      import_contacts!(campaign)
      attach_variant_files!(campaign)
    end

    campaign.start! if campaign.contacts.pending.exists?
    campaign.update!(status: :completed, completed_at: Time.current) unless campaign.contacts.pending.exists?

    render json: { payload: serialize(campaign) }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def start
    @campaign.start!
    render json: { payload: serialize(@campaign) }
  end

  def destroy
    @campaign.destroy!
    head :ok
  end

  def template
    csv = CSV.generate do |rows|
      rows << %w[nome telefone email]
      rows << ['João Exemplo', '+5511999999999', 'joao@example.com']
    end
    send_data csv, filename: 'modelo-campanha-whatsapp-nao-oficial.csv', type: 'text/csv'
  end

  private

  def fetch_campaign
    @campaign = Current.account.unofficial_campaigns.find(params[:id])
  end

  def ensure_feature_enabled
    return if Current.account.feature_enabled?('campaigns')

    render json: { error: I18n.t('unofficial_campaign.errors.disabled') }, status: :not_found
  end

  def campaign_params
    payload = params[:campaign]
    payload = JSON.parse(payload) if payload.is_a?(String)
    ActionController::Parameters.new(payload).permit(
      :title, :start_mode, :scheduled_at,
      :min_contact_interval_seconds, :max_contact_interval_seconds,
      :pause_enabled, :pause_every_min_contacts, :pause_every_max_contacts,
      :pause_min_minutes, :pause_max_minutes, :allowed_start_minute, :allowed_end_minute,
      :post_action, :post_team_id, :post_agent_id,
      sender_inbox_ids: [], allowed_days: []
    )
  end

  def create_messages!(campaign)
    payload = params[:campaign]
    payload = JSON.parse(payload) if payload.is_a?(String)
    messages = Array(payload['messages'])
    raise ArgumentError, I18n.t('unofficial_campaign.errors.messages_required') if messages.empty?

    messages.each_with_index do |message, message_index|
      variants = Array(message['variants'])
      raise ArgumentError, I18n.t('unofficial_campaign.errors.three_variants_required') if variants.size != 3

      record = campaign.messages.create!(
        position: message_index,
        wait_min_seconds: message['wait_min_seconds'] || 3,
        wait_max_seconds: message['wait_max_seconds'] || 8
      )
      variants.each_with_index do |variant, variant_index|
        record.variants.create!(position: variant_index, content: variant['content'])
      end
    end
  end

  def selected_contact_ids
    payload = params[:campaign]
    payload = JSON.parse(payload) if payload.is_a?(String)
    Array(payload['contact_ids']).map(&:to_i).uniq
  end

  def add_selected_contacts!(campaign)
    contact_ids = selected_contact_ids
    Current.account.contacts.where(id: contact_ids).where(campaign_opt_out: false).find_each do |contact|
      campaign.contacts.create!(
        contact: contact,
        name: contact.name,
        phone_number: contact.phone_number,
        source: 'system'
      )
    end
  end

  def import_contacts!(campaign)
    return if params[:contacts_file].blank?

    UnofficialCampaigns::ContactImporter.new(campaign: campaign, file: params[:contacts_file]).perform
  end

  def attach_variant_files!(campaign)
    files = params[:variant_files]
    return if files.blank?

    files.to_unsafe_h.each do |message_position, variants|
      variants.each do |variant_position, variant_files|
        variant = campaign.messages.find_by(position: message_position.to_i)
                          &.variants&.find_by(position: variant_position.to_i)
        next if variant.blank?

        Array(variant_files).each { |file| variant.attachments.attach(file) }
      end
    end
  end

  def serialize(campaign)
    total = campaign.contacts.count
    sent = campaign.contacts.sent.count
    {
      id: campaign.id,
      title: campaign.title,
      status: campaign.status,
      start_mode: campaign.start_mode,
      scheduled_at: campaign.scheduled_at&.iso8601,
      started_at: campaign.started_at&.iso8601,
      completed_at: campaign.completed_at&.iso8601,
      total_contacts: total,
      sent_contacts: sent,
      failed_contacts: campaign.contacts.failed.count,
      opted_out_contacts: campaign.contacts.opted_out.count,
      sender_inbox_ids: campaign.sender_inbox_ids,
      created_at: campaign.created_at.iso8601
    }
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity
