/* global axios */
import ApiClient from './ApiClient';

class SmartReceptionAPI extends ApiClient {
  constructor() {
    super('inboxes', { accountScoped: true });
  }

  show(inboxId) {
    return axios.get(`${this.url}/${inboxId}/smart_reception_setting`);
  }

  update(inboxId, data) {
    return axios.patch(`${this.url}/${inboxId}/smart_reception_setting`, data);
  }

  uploadAttachment(inboxId, { file, keywords, caption }) {
    const formData = new FormData();
    formData.append('file', file);
    formData.append('keywords', keywords);
    formData.append('caption', caption || '');
    return axios.post(
      `${this.url}/${inboxId}/smart_reception_attachments`,
      formData,
      { headers: { 'Content-Type': 'multipart/form-data' } }
    );
  }

  deleteAttachment(inboxId, attachmentId) {
    return axios.delete(
      `${this.url}/${inboxId}/smart_reception_attachments/${attachmentId}`
    );
  }
}

export default new SmartReceptionAPI();
