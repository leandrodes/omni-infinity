/* global axios */
import ApiClient from './ApiClient';

class InboxMembers extends ApiClient {
  constructor() {
    super('inbox_members', { accountScoped: true });
  }

  update({ inboxId, agentList, priorityLevels = {} }) {
    return axios.patch(this.url, {
      inbox_id: inboxId,
      user_ids: agentList,
      priority_levels: priorityLevels,
    });
  }
}

export default new InboxMembers();
