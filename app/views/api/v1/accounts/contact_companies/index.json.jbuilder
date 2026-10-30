json.meta do
  json.count @companies_count
  json.current_page @current_page
end

json.payload do
  json.array! @companies do |company|
    json.name company[:name]
    json.contacts_count company[:contacts_count]
  end
end
