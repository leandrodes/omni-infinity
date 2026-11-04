import { computed } from 'vue';
import { useRoute } from 'vue-router';
import {
  frontendURL,
  conversationUrl,
  conversationListPageURL,
} from 'dashboard/helper/URLHelper';
import {
  isOnMentionsView,
  isOnParticipatingView,
  isOnUnattendedView,
  isOnOpenTeamView,
  isOnUnassignedView,
  isOnAIView,
  isOnFoldersView,
} from 'dashboard/store/modules/conversations/helpers/actionHelpers';
import wootConstants from 'dashboard/constants/globals';

// Builds conversation and list paths that keep the active route's context.
export function useConversationRoutePath() {
  const route = useRoute();

  const buildConversationPath = (
    conversationId,
    { keepFolderScope = true } = {}
  ) => {
    const {
      params: { accountId, inbox_id: inboxId, label, teamId },
      name,
    } = route;

    let conversationType = '';
    if (isOnMentionsView({ route: { name } })) {
      conversationType = 'mention';
    } else if (isOnParticipatingView({ route: { name } })) {
      conversationType = 'participating';
    } else if (isOnUnattendedView({ route: { name } })) {
      conversationType = 'unattended';
    } else if (isOnOpenTeamView({ route: { name } })) {
      conversationType = 'open_team';
    } else if (isOnUnassignedView({ route: { name } })) {
      conversationType = 'unassigned';
    } else if (isOnAIView({ route: { name } })) {
      conversationType = 'ai';
    }

    const isOnFolder = isOnFoldersView({ route: { name } });

    return frontendURL(
      conversationUrl({
        accountId,
        activeInbox: inboxId,
        id: conversationId,
        label,
        teamId,
        foldersId: keepFolderScope && isOnFolder ? route.params.id : 0,
        conversationType,
      })
    );
  };

  const buildConversationListPath = ({ keepFolderScope = true } = {}) => {
    const {
      params: { accountId, inbox_id: inboxId, label, teamId },
      name,
    } = route;
    const { CONVERSATION_TYPE } = wootConstants;

    let conversationType = '';
    if (isOnMentionsView({ route: { name } })) {
      conversationType = CONVERSATION_TYPE.MENTION;
    } else if (isOnParticipatingView({ route: { name } })) {
      conversationType = CONVERSATION_TYPE.PARTICIPATING;
    } else if (isOnUnattendedView({ route: { name } })) {
      conversationType = CONVERSATION_TYPE.UNATTENDED;
    } else if (isOnOpenTeamView({ route: { name } })) {
      conversationType = CONVERSATION_TYPE.OPEN_TEAM;
    } else if (isOnUnassignedView({ route: { name } })) {
      conversationType = CONVERSATION_TYPE.UNASSIGNED;
    } else if (isOnAIView({ route: { name } })) {
      conversationType = CONVERSATION_TYPE.AI;
    }

    const isOnFolder = isOnFoldersView({ route: { name } });

    return conversationListPageURL({
      accountId,
      conversationType,
      customViewId: keepFolderScope && isOnFolder ? route.params.id : 0,
      inboxId,
      label,
      teamId,
    });
  };

  const isOnFolderView = computed(() =>
    isOnFoldersView({ route: { name: route.name } })
  );

  return { buildConversationPath, buildConversationListPath, isOnFolderView };
}
