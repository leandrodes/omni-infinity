/* eslint arrow-body-style: 0 */
import { frontendURL } from '../../../helper/URLHelper';
import store from '../../../store';
import ConversationView from './ConversationView.vue';

const CONVERSATION_PERMISSIONS = [
  'administrator',
  'agent',
  'conversation_manage',
  'conversation_unassigned_manage',
  'conversation_participating_manage',
];

const isFolderAvailable = async folderId => {
  let folders = store.getters['customViews/getConversationCustomViews'];
  if (!folders.length) {
    await store.dispatch('customViews/get', 'conversation');
    folders = store.getters['customViews/getConversationCustomViews'];
  }
  return folders.some(folder => folder.id === Number(folderId));
};

const redirectFolderListIfUnavailable = async (to, _from, next) => {
  if (await isFolderAvailable(to.params.id)) {
    next();
    return;
  }
  next({ name: 'home', params: { accountId: to.params.accountId } });
};

const redirectFolderConversationIfUnavailable = async (to, _from, next) => {
  if (await isFolderAvailable(to.params.id)) {
    next();
    return;
  }
  next({
    name: 'inbox_conversation',
    params: {
      accountId: to.params.accountId,
      conversation_id: to.params.conversation_id,
    },
  });
};

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/dashboard'),
      name: 'home',
      meta: {
        permissions: CONVERSATION_PERMISSIONS,
      },
      component: ConversationView,
      props: () => {
        return { inboxId: 0, conversationType: 'open_mine' };
      },
    },
    {
      path: frontendURL('accounts/:accountId/open/team/conversations'),
      name: 'conversation_open_team',
      meta: {
        permissions: CONVERSATION_PERMISSIONS,
      },
      component: ConversationView,
      props: () => ({ conversationType: 'open_team' }),
    },
    {
      path: frontendURL(
        'accounts/:accountId/open/team/conversations/:conversationId'
      ),
      name: 'conversation_through_open_team',
      meta: {
        permissions: CONVERSATION_PERMISSIONS,
      },
      component: ConversationView,
      props: route => ({
        conversationId: route.params.conversationId,
        conversationType: 'open_team',
      }),
    },
    {
      path: frontendURL('accounts/:accountId/unassigned/conversations'),
      name: 'conversation_unassigned',
      meta: {
        permissions: CONVERSATION_PERMISSIONS,
      },
      component: ConversationView,
      props: () => ({ conversationType: 'unassigned' }),
    },
    {
      path: frontendURL(
        'accounts/:accountId/unassigned/conversations/:conversationId'
      ),
      name: 'conversation_through_unassigned',
      meta: {
        permissions: CONVERSATION_PERMISSIONS,
      },
      component: ConversationView,
      props: route => ({
        conversationId: route.params.conversationId,
        conversationType: 'unassigned',
      }),
    },
    {
      path: frontendURL('accounts/:accountId/conversations/:conversation_id'),
      name: 'inbox_conversation',
      meta: {
        permissions: CONVERSATION_PERMISSIONS,
      },
      component: ConversationView,
      props: route => {
        return {
          inboxId: 0,
          conversationId: route.params.conversation_id,
          conversationType: 'open_mine',
        };
      },
    },
    {
      path: frontendURL('accounts/:accountId/inbox/:inbox_id'),
      name: 'inbox_dashboard',
      meta: {
        permissions: CONVERSATION_PERMISSIONS,
      },
      component: ConversationView,
      props: route => {
        return { inboxId: route.params.inbox_id };
      },
    },
    {
      path: frontendURL(
        'accounts/:accountId/inbox/:inbox_id/conversations/:conversation_id'
      ),
      name: 'conversation_through_inbox',
      meta: {
        permissions: CONVERSATION_PERMISSIONS,
      },
      component: ConversationView,
      props: route => {
        return {
          conversationId: route.params.conversation_id,
          inboxId: route.params.inbox_id,
        };
      },
    },
    {
      path: frontendURL('accounts/:accountId/label/:label'),
      name: 'label_conversations',
      meta: {
        permissions: CONVERSATION_PERMISSIONS,
      },
      component: ConversationView,
      props: route => ({ label: route.params.label }),
    },
    {
      path: frontendURL(
        'accounts/:accountId/label/:label/conversations/:conversation_id'
      ),
      name: 'conversations_through_label',
      meta: {
        permissions: CONVERSATION_PERMISSIONS,
      },
      component: ConversationView,
      props: route => ({
        conversationId: route.params.conversation_id,
        label: route.params.label,
      }),
    },
    {
      path: frontendURL('accounts/:accountId/team/:teamId'),
      name: 'team_conversations',
      meta: {
        permissions: CONVERSATION_PERMISSIONS,
      },
      component: ConversationView,
      props: route => ({ teamId: route.params.teamId }),
    },
    {
      path: frontendURL(
        'accounts/:accountId/team/:teamId/conversations/:conversationId'
      ),
      name: 'conversations_through_team',
      meta: {
        permissions: CONVERSATION_PERMISSIONS,
      },
      component: ConversationView,
      props: route => ({
        conversationId: route.params.conversationId,
        teamId: route.params.teamId,
      }),
    },
    {
      path: frontendURL('accounts/:accountId/custom_view/:id'),
      name: 'folder_conversations',
      meta: {
        permissions: CONVERSATION_PERMISSIONS,
      },
      beforeEnter: redirectFolderListIfUnavailable,
      component: ConversationView,
      props: route => ({ foldersId: route.params.id }),
    },
    {
      path: frontendURL(
        'accounts/:accountId/custom_view/:id/conversations/:conversation_id'
      ),
      name: 'conversations_through_folders',
      meta: {
        permissions: CONVERSATION_PERMISSIONS,
      },
      component: ConversationView,
      beforeEnter: redirectFolderConversationIfUnavailable,
      props: route => ({
        conversationId: route.params.conversation_id,
        foldersId: route.params.id,
      }),
    },
    {
      path: frontendURL('accounts/:accountId/mentions/conversations'),
      name: 'conversation_mentions',
      meta: {
        permissions: CONVERSATION_PERMISSIONS,
      },
      component: ConversationView,
      props: () => ({ conversationType: 'mention' }),
    },
    {
      path: frontendURL(
        'accounts/:accountId/mentions/conversations/:conversationId'
      ),
      name: 'conversation_through_mentions',
      meta: {
        permissions: CONVERSATION_PERMISSIONS,
      },
      component: ConversationView,
      props: route => ({
        conversationId: route.params.conversationId,
        conversationType: 'mention',
      }),
    },
    {
      path: frontendURL('accounts/:accountId/resolved/conversations'),
      name: 'conversation_resolved',
      meta: {
        permissions: CONVERSATION_PERMISSIONS,
      },
      component: ConversationView,
      props: () => ({ conversationType: 'resolved' }),
    },
    {
      path: frontendURL(
        'accounts/:accountId/resolved/conversations/:conversationId'
      ),
      name: 'conversation_through_resolved',
      meta: {
        permissions: CONVERSATION_PERMISSIONS,
      },
      component: ConversationView,
      props: route => ({
        conversationId: route.params.conversationId,
        conversationType: 'resolved',
      }),
    },
    {
      path: frontendURL('accounts/:accountId/chatbot/conversations'),
      name: 'conversation_chatbot',
      meta: {
        permissions: CONVERSATION_PERMISSIONS,
      },
      component: ConversationView,
      props: () => ({ conversationType: 'chatbot' }),
    },
    {
      path: frontendURL(
        'accounts/:accountId/chatbot/conversations/:conversationId'
      ),
      name: 'conversation_through_chatbot',
      meta: {
        permissions: CONVERSATION_PERMISSIONS,
      },
      component: ConversationView,
      props: route => ({
        conversationId: route.params.conversationId,
        conversationType: 'chatbot',
      }),
    },
    {
      path: frontendURL('accounts/:accountId/pending/conversations'),
      name: 'conversation_pending',
      meta: {
        permissions: CONVERSATION_PERMISSIONS,
      },
      component: ConversationView,
      props: () => ({ conversationType: 'pending' }),
    },
    {
      path: frontendURL(
        'accounts/:accountId/pending/conversations/:conversationId'
      ),
      name: 'conversation_through_pending',
      meta: {
        permissions: CONVERSATION_PERMISSIONS,
      },
      component: ConversationView,
      props: route => ({
        conversationId: route.params.conversationId,
        conversationType: 'pending',
      }),
    },
    {
      path: frontendURL('accounts/:accountId/unattended/conversations'),
      name: 'conversation_unattended',
      meta: {
        permissions: CONVERSATION_PERMISSIONS,
      },
      component: ConversationView,
      props: () => ({ conversationType: 'unattended' }),
    },
    {
      path: frontendURL(
        'accounts/:accountId/unattended/conversations/:conversationId'
      ),
      name: 'conversation_through_unattended',
      meta: {
        permissions: CONVERSATION_PERMISSIONS,
      },
      component: ConversationView,
      props: route => ({
        conversationId: route.params.conversationId,
        conversationType: 'unattended',
      }),
    },
    {
      path: frontendURL('accounts/:accountId/participating/conversations'),
      name: 'conversation_participating',
      meta: {
        permissions: CONVERSATION_PERMISSIONS,
      },
      component: ConversationView,
      props: () => ({ conversationType: 'participating' }),
    },
    {
      path: frontendURL(
        'accounts/:accountId/participating/conversations/:conversationId'
      ),
      name: 'conversation_through_participating',
      meta: {
        permissions: CONVERSATION_PERMISSIONS,
      },
      component: ConversationView,
      props: route => ({
        conversationId: route.params.conversationId,
        conversationType: 'participating',
      }),
    },
  ],
};
