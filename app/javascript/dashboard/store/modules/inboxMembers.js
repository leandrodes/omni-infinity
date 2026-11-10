import InboxMembersAPI from '../../api/inboxMembers';

export const actions = {
  get(_, { inboxId }) {
    return InboxMembersAPI.show(inboxId);
  },
  create(_, { inboxId, agentList, priorityLevels }) {
    return InboxMembersAPI.update({ inboxId, agentList, priorityLevels });
  },
};

export default {
  namespaced: true,
  actions,
};
