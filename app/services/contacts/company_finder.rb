class Contacts::CompanyFinder
  RESULTS_PER_PAGE = 15

  attr_reader :account, :params

  def initialize(account, params)
    @account = account
    @params = params
  end

  def perform
    {
      companies: companies,
      count: count,
      current_page: current_page
    }
  end

  private

  def companies
    result = scope.group(Arel.sql(normalized_name))
    result = result.select(Arel.sql(select_sql))
    result = result.order(Arel.sql("#{normalized_name} ASC"))
    result.limit(RESULTS_PER_PAGE).offset((current_page - 1) * RESULTS_PER_PAGE)
  end

  def count
    scope.distinct.count(Arel.sql(normalized_name))
  end

  def scope
    result = contacts.where("#{company_name} <> ''")
    result = result.where("#{company_name} ILIKE ?", "%#{params[:search].strip}%") if params[:search].present?
    result
  end

  def contacts
    @contacts ||= account.contacts.resolved_contacts(use_crm_v2: account.feature_enabled?('crm_v2'))
  end

  def current_page
    @current_page ||= (params[:page] || 1).to_i
  end

  def company_name
    "BTRIM(contacts.additional_attributes->>'company_name')"
  end

  def normalized_name
    "LOWER(#{company_name})"
  end

  def select_sql
    "#{normalized_name} AS normalized_name, MIN(#{company_name}) AS name, COUNT(*) AS contacts_count"
  end
end
