class Api::V1::Accounts::ContactCompaniesController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def index
    result = Contacts::CompanyFinder.new(Current.account, params).perform
    @companies = result[:companies]
    @companies_count = result[:count]
    @current_page = result[:current_page]
  end

  private

  def check_authorization
    authorize(Contact)
  end
end
