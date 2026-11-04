/* global axios */
import ApiClient from './ApiClient';

class UnofficialCampaignsAPI extends ApiClient {
  constructor() {
    super('unofficial_campaigns', { accountScoped: true });
  }

  createCampaign(payload) {
    return axios.post(this.url, payload, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }

  start(id) {
    return axios.post(`${this.url}/${id}/start`);
  }

  templateURL() {
    return `${this.url}/template`;
  }

  downloadTemplate() {
    return axios.get(this.templateURL(), { responseType: 'blob' });
  }

  getOptOutWords() {
    return axios.get(`${this.baseUrl()}/campaign_opt_out_settings`);
  }

  updateOptOutWords(words) {
    return axios.patch(`${this.baseUrl()}/campaign_opt_out_settings`, {
      words,
    });
  }
}

export default new UnofficialCampaignsAPI();
