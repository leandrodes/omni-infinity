class Api::V1::Accounts::Contacts::ContactAttachmentsController < Api::V1::Accounts::Contacts::BaseController
  before_action :authorize_contact
  before_action :fetch_attachment, only: [:destroy]

  def index
    @attachments = @contact.contact_attachments
                           .includes(file_attachment: :blob)
                           .order(created_at: :desc)
  end

  def create
    files = Array(params[:files] || params[:file]).compact
    return render json: { error: I18n.t('errors.contacts.attachments.file_required') }, status: :unprocessable_entity if files.blank?

    ActiveRecord::Base.transaction do
      @attachments = files.map do |file|
        @contact.contact_attachments.create!(account: Current.account, file: file)
      end
    end

    @attachments = @contact.contact_attachments
                           .includes(file_attachment: :blob)
                           .order(created_at: :desc)
    render :index
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def destroy
    @attachment.destroy!
    head :ok
  end

  private

  def authorize_contact
    authorize @contact, :show?
  end

  def fetch_attachment
    @attachment = @contact.contact_attachments.find(params[:id])
  end
end
