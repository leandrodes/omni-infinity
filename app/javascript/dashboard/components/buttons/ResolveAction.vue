<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useToggle } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { useEmitter } from 'dashboard/composables/emitter';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import { useConversationRequiredAttributes } from 'dashboard/composables/useConversationRequiredAttributes';
import { useConversationRoutePath } from 'dashboard/composables/useConversationRoutePath';

import WootDropdownItem from 'shared/components/ui/dropdown/DropdownItem.vue';
import WootDropdownMenu from 'shared/components/ui/dropdown/DropdownMenu.vue';
import wootConstants from 'dashboard/constants/globals';
import {
  CMD_REOPEN_CONVERSATION,
  CMD_RESOLVE_CONVERSATION,
} from 'dashboard/helper/commandbar/events';

import ButtonGroup from 'dashboard/components-next/buttonGroup/ButtonGroup.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ConversationResolveAttributesModal from 'dashboard/components-next/ConversationWorkflow/ConversationResolveAttributesModal.vue';
import ConversationStatusConfirmationModal from 'dashboard/components-next/ConversationWorkflow/ConversationStatusConfirmationModal.vue';

const store = useStore();
const getters = useStoreGetters();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const { checkMissingAttributes } = useConversationRequiredAttributes();
const { buildConversationListPath, buildConversationPath } =
  useConversationRoutePath();

const arrowDownButtonRef = ref(null);
const isLoading = ref(false);
const resolveAttributesModalRef = ref(null);
const statusConfirmationModalRef = ref(null);

const [showActionsDropdown, toggleDropdown] = useToggle();
const closeDropdown = () => toggleDropdown(false);
const openDropdown = () => toggleDropdown(true);

const currentChat = computed(() => getters.getSelectedChat.value);
const isOnInboxView = computed(() =>
  String(route.name || '').startsWith('inbox_view')
);

const isOpen = computed(
  () => currentChat.value.status === wootConstants.STATUS_TYPE.OPEN
);
const isPending = computed(
  () => currentChat.value.status === wootConstants.STATUS_TYPE.PENDING
);
const isResolved = computed(
  () => currentChat.value.status === wootConstants.STATUS_TYPE.RESOLVED
);
const isSnoozed = computed(
  () => currentChat.value.status === wootConstants.STATUS_TYPE.SNOOZED
);

const showAdditionalActions = computed(
  () => !isPending.value && !isSnoozed.value
);

const showOpenButton = computed(() => {
  return isPending.value || isSnoozed.value;
});

const getConversationParams = () => {
  const allConversations = document.querySelectorAll(
    '.conversations-list .conversation'
  );

  const activeConversation = document.querySelector(
    'div.conversations-list div.conversation.active'
  );
  const activeConversationIndex = [...allConversations].indexOf(
    activeConversation
  );
  const lastConversationIndex = allConversations.length - 1;

  return {
    all: allConversations,
    activeIndex: activeConversationIndex,
    lastIndex: lastConversationIndex,
  };
};

const openSnoozeModal = () => {
  const ninja = document.querySelector('ninja-keys');
  ninja.open({ parent: 'snooze_conversation' });
};

const executeStatusChange = async (
  conversationId,
  status,
  snoozedUntil,
  { customAttributes = null, farewellMessage = null } = {}
) => {
  isLoading.value = true;

  const payload = {
    conversationId,
    status,
    snoozedUntil,
  };

  if (customAttributes) {
    payload.customAttributes = customAttributes;
  }

  try {
    if (farewellMessage?.content) {
      await store.dispatch('createPendingMessageAndSend', {
        conversationId,
        message: farewellMessage.content,
        private: false,
      });
    }

    await store.dispatch('toggleStatus', payload);
    useAlert(t('CONVERSATION.CHANGE_STATUS'));

    if (status === wootConstants.STATUS_TYPE.RESOLVED) {
      store.dispatch('clearSelectedState');
      router.replace(buildConversationListPath());
    } else if (
      status === wootConstants.STATUS_TYPE.OPEN &&
      isOnInboxView.value
    ) {
      router.push(buildConversationPath(conversationId));
    }
  } catch (error) {
    if (error?.response?.status === 403) {
      useAlert(t('CONVERSATION.NO_PERMISSION_REOPEN'));
    } else if (farewellMessage) {
      useAlert(t('CONVERSATION.MESSAGE_ERROR'));
    }
  } finally {
    isLoading.value = false;
  }
};

const requestStatusChange = status => {
  closeDropdown();
  statusConfirmationModalRef.value?.open({
    conversation: currentChat.value,
    status,
    snoozedUntil: null,
  });
};

const handleStatusConfirmed = payload => {
  const conversation = getters.getConversationById.value(payload.id);
  const currentCustomAttributes = conversation?.custom_attributes || {};

  if (payload.status === wootConstants.STATUS_TYPE.RESOLVED) {
    const { hasMissing, missing } = checkMissingAttributes(
      currentCustomAttributes,
      conversation?.meta?.team?.id
    );

    if (hasMissing) {
      resolveAttributesModalRef.value?.open(missing, currentCustomAttributes, {
        id: payload.id,
        snoozedUntil: payload.snoozedUntil,
        farewellMessage: payload.farewellMessage,
      });
      return;
    }
  }

  executeStatusChange(payload.id, payload.status, payload.snoozedUntil, {
    farewellMessage: payload.farewellMessage,
  });
};

const handleResolveWithAttributes = ({ attributes, context }) => {
  if (context) {
    const conversation = getters.getConversationById.value(context.id);
    const currentCustomAttributes = conversation?.custom_attributes || {};
    const mergedAttributes = { ...currentCustomAttributes, ...attributes };
    executeStatusChange(
      context.id,
      wootConstants.STATUS_TYPE.RESOLVED,
      context.snoozedUntil,
      {
        customAttributes: mergedAttributes,
        farewellMessage: context.farewellMessage,
      }
    );
  }
};

const onCmdOpenConversation = () => {
  requestStatusChange(wootConstants.STATUS_TYPE.OPEN);
};

const onCmdResolveConversation = () => {
  requestStatusChange(wootConstants.STATUS_TYPE.RESOLVED);
};

const keyboardEvents = {
  'Alt+KeyM': {
    action: () => arrowDownButtonRef.value?.$el.click(),
    allowOnFocusedInput: true,
  },
  'Alt+KeyE': {
    action: async event => {
      // Chrome on Windows treats Alt+E as a legacy shortcut for its own
      // menu (Alt+E / Alt+F both open "Customize and control Google
      // Chrome"). Without preventDefault, our resolve action still runs,
      // but Chrome's menu also opens on top of it.
      event.preventDefault();
      onCmdResolveConversation();
    },
  },
  '$mod+Alt+KeyE': {
    action: async event => {
      const { all, activeIndex, lastIndex } = getConversationParams();
      onCmdResolveConversation();

      if (activeIndex < lastIndex) {
        all[activeIndex + 1].click();
      } else if (all.length > 1) {
        all[0].click();
        document.querySelector('.conversations-list').scrollTop = 0;
      }
      event.preventDefault();
    },
  },
};

onMounted(() => {
  store.dispatch('attributes/get');
});

useKeyboardEvents(keyboardEvents);

useEmitter(CMD_REOPEN_CONVERSATION, onCmdOpenConversation);
useEmitter(CMD_RESOLVE_CONVERSATION, onCmdResolveConversation);
</script>

<template>
  <div class="flex relative justify-end items-center resolve-actions">
    <ButtonGroup
      class="flex-shrink-0 rounded-lg shadow outline-1 outline"
      :class="!showOpenButton ? 'outline-n-container' : 'outline-transparent'"
    >
      <Button
        v-if="isOpen"
        :label="t('CONVERSATION.HEADER.RESOLVE_ACTION')"
        size="sm"
        color="slate"
        no-animation
        class="ltr:rounded-r-none rtl:rounded-l-none !outline-0"
        :is-loading="isLoading"
        @click="onCmdResolveConversation"
      />
      <Button
        v-else-if="isResolved"
        :label="t('CONVERSATION.HEADER.REOPEN_ACTION')"
        size="sm"
        color="slate"
        no-animation
        class="ltr:rounded-r-none rtl:rounded-l-none !outline-0"
        :is-loading="isLoading"
        @click="onCmdOpenConversation"
      />
      <Button
        v-else-if="showOpenButton"
        :label="t('CONVERSATION.HEADER.OPEN_ACTION')"
        size="sm"
        color="slate"
        no-animation
        :is-loading="isLoading"
        @click="onCmdOpenConversation"
      />
      <Button
        v-if="showAdditionalActions"
        ref="arrowDownButtonRef"
        icon="i-lucide-chevron-down"
        :disabled="isLoading"
        size="sm"
        no-animation
        class="ltr:rounded-l-none rtl:rounded-r-none !outline-0"
        color="slate"
        trailing-icon
        @click="openDropdown"
      />
    </ButtonGroup>
    <div
      v-if="showActionsDropdown"
      v-on-clickaway="closeDropdown"
      class="border rounded-lg shadow-lg border-n-strong dark:border-n-strong box-content p-2 w-fit z-10 bg-n-alpha-3 backdrop-blur-[100px] absolute block left-auto top-full mt-0.5 start-0 xl:start-auto xl:end-0 max-w-[12.5rem] min-w-[9.75rem] [&_ul>li]:mb-0"
    >
      <WootDropdownMenu class="mb-0">
        <WootDropdownItem v-if="!isPending">
          <Button
            :label="t('CONVERSATION.RESOLVE_DROPDOWN.SNOOZE_UNTIL')"
            ghost
            slate
            sm
            start
            icon="i-lucide-alarm-clock-minus"
            class="w-full"
            @click="() => openSnoozeModal()"
          />
        </WootDropdownItem>
        <WootDropdownItem v-if="!isPending">
          <Button
            :label="t('CONVERSATION.RESOLVE_DROPDOWN.MARK_PENDING')"
            ghost
            slate
            sm
            start
            icon="i-lucide-circle-dot-dashed"
            class="w-full"
            @click="
              () => requestStatusChange(wootConstants.STATUS_TYPE.PENDING)
            "
          />
        </WootDropdownItem>
      </WootDropdownMenu>
    </div>
    <ConversationStatusConfirmationModal
      ref="statusConfirmationModalRef"
      @confirm="handleStatusConfirmed"
    />
    <ConversationResolveAttributesModal
      ref="resolveAttributesModalRef"
      @submit="handleResolveWithAttributes"
    />
  </div>
</template>
