/* global axios */
import ApiClient from './ApiClient';

class TranscriptionSettings extends ApiClient {
  constructor() {
    super('transcription_settings', { accountScoped: true });
  }

  getSettings() {
    return axios.get(this.url);
  }

  updateSettings(data) {
    return axios.patch(this.url, data);
  }
}

export default new TranscriptionSettings();
