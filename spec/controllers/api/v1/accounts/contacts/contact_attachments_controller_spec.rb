require 'rails_helper'

RSpec.describe '/api/v1/accounts/{account.id}/contacts/:contact_id/contact_attachments', type: :request do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:pdf_file) { fixture_file_upload('spec/fixtures/files/sample.pdf', 'application/pdf') }
  let(:url) { "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/contact_attachments" }

  describe 'GET contact_attachments' do
    it 'returns unauthorized when unauthenticated' do
      get url

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns the contact files for account agents' do
      create(:contact_attachment, account: account, contact: contact, file: pdf_file)

      get url, headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload'].length).to eq(1)
      attachment = response.parsed_body['payload'].first
      expect(attachment).to include('filename', 'file_type', 'data_url')
      expect(attachment['filename']).to eq('sample.pdf')
      expect(attachment['file_type']).to eq('file')
    end
  end

  describe 'POST contact_attachments' do
    it 'uploads one or more files' do
      expect do
        post url, params: { files: [pdf_file] }, headers: admin.create_new_auth_token
      end.to change(ContactAttachment, :count).by(1)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload'].first['filename']).to eq('sample.pdf')
    end

    it 'rejects dangerous file extensions' do
      tempfile = Tempfile.new(['malware', '.exe'])
      tempfile.write('MZ')
      tempfile.rewind
      upload = Rack::Test::UploadedFile.new(tempfile.path, 'application/x-msdownload')

      expect do
        post url, params: { files: [upload] }, headers: admin.create_new_auth_token
      end.not_to change(ContactAttachment, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to include('not allowed')
    ensure
      tempfile&.close!
    end
  end

  describe 'DELETE contact_attachment' do
    it 'deletes a contact file' do
      attachment = create(:contact_attachment, account: account, contact: contact, file: pdf_file)

      expect do
        delete "#{url}/#{attachment.id}", headers: admin.create_new_auth_token
      end.to change(ContactAttachment, :count).by(-1)

      expect(response).to have_http_status(:success)
    end
  end
end
