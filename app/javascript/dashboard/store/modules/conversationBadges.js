import ConversationAPI from '../../api/conversations';
import types from '../mutation-types';

const normalizeCount = count => {
  const parsedCount = Number(count);
  return Number.isFinite(parsedCount) && parsedCount > 0 ? parsedCount : 0;
};

export const state = {
  openMineCount: 0,
  openTeamCount: 0,
  chatbotCount: 0,
  aiCount: 0,
  unattendedCount: 0,
  unattendedMineCount: 0,
  unattendedParticipatingCount: 0,
  unassignedCount: 0,
  participatingCount: 0,
  pendingCount: 0,
  pendingMineCount: 0,
  pendingParticipatingCount: 0,
};

export const getters = {
  getOpenMineCount: $state => $state.openMineCount,
  getOpenTeamCount: $state => $state.openTeamCount,
  getChatbotCount: $state => $state.chatbotCount,
  getAiCount: $state => $state.aiCount,
  getUnattendedCount: $state => $state.unattendedCount,
  getUnattendedMineCount: $state => $state.unattendedMineCount,
  getUnattendedParticipatingCount: $state =>
    $state.unattendedParticipatingCount,
  getUnassignedCount: $state => $state.unassignedCount,
  getParticipatingCount: $state => $state.participatingCount,
  getPendingCount: $state => $state.pendingCount,
  getPendingMineCount: $state => $state.pendingMineCount,
  getPendingParticipatingCount: $state => $state.pendingParticipatingCount,
};

export const actions = {
  async get({ commit }) {
    try {
      const { data } = await ConversationAPI.getUnreadBadges();
      commit(types.SET_CONVERSATION_BADGES, data.payload);
    } catch (error) {
      // Keep the last known badges when the request fails.
    }
  },
};

export const mutations = {
  [types.SET_CONVERSATION_BADGES]($state, payload = {}) {
    $state.openMineCount = normalizeCount(payload.open_mine_count);
    $state.openTeamCount = normalizeCount(payload.open_team_count);
    $state.chatbotCount = normalizeCount(payload.chatbot_count);
    $state.aiCount = normalizeCount(payload.ai_count);
    $state.unattendedCount = normalizeCount(payload.unattended_count);
    $state.unattendedMineCount = normalizeCount(payload.unattended_mine_count);
    $state.unattendedParticipatingCount = normalizeCount(
      payload.unattended_participating_count
    );
    $state.unassignedCount = normalizeCount(payload.unassigned_count);
    $state.participatingCount = normalizeCount(payload.participating_count);
    $state.pendingCount = normalizeCount(payload.pending_count);
    $state.pendingMineCount = normalizeCount(payload.pending_mine_count);
    $state.pendingParticipatingCount = normalizeCount(
      payload.pending_participating_count
    );
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
