/* global axios */
import ApiClient from './ApiClient';

class UnofficialWhatsapp extends ApiClient {
  constructor() {
    super('unofficial_whatsapp/instances', { accountScoped: true });
  }

  connect(inboxId) {
    return axios.post(`${this.url}/${inboxId}`);
  }

  qrcode(inboxId) {
    return axios.get(`${this.url}/${inboxId}/qrcode`);
  }

  status(inboxId) {
    return axios.get(`${this.url}/${inboxId}/status`);
  }

  logout(inboxId) {
    return axios.post(`${this.url}/${inboxId}/logout`);
  }
}

export default new UnofficialWhatsapp();
