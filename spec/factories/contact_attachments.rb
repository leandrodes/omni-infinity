FactoryBot.define do
  factory :contact_attachment do
    account
    contact
    file { fixture_file_upload(Rails.root.join('spec/fixtures/files/sample.pdf'), 'application/pdf') }
  end
end
