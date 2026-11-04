<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import wootConstants from 'dashboard/constants/globals';

const emit = defineEmits(['confirm', 'close']);

const { t } = useI18n();
const store = useStore();
const { getPlainText } = useMessageFormatter();
const farewellMessages = useMapGetter('getFarewellMessages');

const dialogRef = ref(null);
const currentStatus = ref('');
const targetStatus = ref('');
const conversationContext = ref(null);
const selectedFarewellId = ref(null);
const isLoadingFarewells = ref(false);

const statusLabel = status =>
  t(`CONVERSATION.STATUS_CONFIRMATION.STATUS.${status || 'unknown'}`);

const title = computed(() => {
  if (
    currentStatus.value === wootConstants.STATUS_TYPE.RESOLVED &&
    targetStatus.value === wootConstants.STATUS_TYPE.OPEN
  ) {
    return t('CONVERSATION.STATUS_CONFIRMATION.REOPEN_TITLE');
  }

  return t('CONVERSATION.STATUS_CONFIRMATION.TITLE', {
    from: statusLabel(currentStatus.value),
    to: statusLabel(targetStatus.value),
  });
});

const isResolving = computed(
  () => targetStatus.value === wootConstants.STATUS_TYPE.RESOLVED
);

const selectedFarewell = computed(() =>
  farewellMessages.value.find(
    message => Number(message.id) === Number(selectedFarewellId.value)
  )
);

const farewellPreview = message =>
  getPlainText(message.content || '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 160);

const loadFarewellMessages = async () => {
  isLoadingFarewells.value = true;
  try {
    await store.dispatch('getCannedResponse');
  } finally {
    isLoadingFarewells.value = false;
  }
};

const open = async ({ conversation, status, snoozedUntil, ...context }) => {
  currentStatus.value = conversation?.status || '';
  targetStatus.value = status;
  conversationContext.value = {
    id: conversation?.id,
    snoozedUntil,
    ...context,
  };
  selectedFarewellId.value = null;
  dialogRef.value?.open();

  if (status === wootConstants.STATUS_TYPE.RESOLVED) {
    await loadFarewellMessages();
  }
};

const close = () => dialogRef.value?.close();

const handleClose = () => {
  currentStatus.value = '';
  targetStatus.value = '';
  conversationContext.value = null;
  selectedFarewellId.value = null;
  emit('close');
};

const handleConfirm = () => {
  emit('confirm', {
    ...conversationContext.value,
    status: targetStatus.value,
    farewellMessage: selectedFarewell.value || null,
  });
  close();
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="lg"
    :title="title"
    :description="
      isResolving
        ? t('CONVERSATION.STATUS_CONFIRMATION.RESOLVE_DESCRIPTION')
        : t('CONVERSATION.STATUS_CONFIRMATION.DESCRIPTION')
    "
    :confirm-button-label="t('CONVERSATION.STATUS_CONFIRMATION.CONFIRM')"
    :cancel-button-label="t('CONVERSATION.STATUS_CONFIRMATION.CANCEL')"
    @confirm="handleConfirm"
    @close="handleClose"
  >
    <div v-if="isResolving" class="flex flex-col gap-3">
      <div class="flex flex-col gap-1">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('CONVERSATION.STATUS_CONFIRMATION.FAREWELL.TITLE') }}
        </span>
        <span class="text-sm text-n-slate-11">
          {{ t('CONVERSATION.STATUS_CONFIRMATION.FAREWELL.DESCRIPTION') }}
        </span>
      </div>

      <div v-if="isLoadingFarewells" class="py-4 text-sm text-n-slate-11">
        {{ t('CONVERSATION.STATUS_CONFIRMATION.FAREWELL.LOADING') }}
      </div>

      <div
        v-else-if="farewellMessages.length"
        class="flex flex-col gap-2 max-h-72 overflow-y-auto"
      >
        <label
          class="flex items-start gap-3 p-3 border rounded-lg cursor-pointer border-n-weak hover:bg-n-alpha-black2"
        >
          <input
            v-model="selectedFarewellId"
            type="radio"
            :value="null"
            class="mt-1"
          />
          <span class="flex flex-col gap-1">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('CONVERSATION.STATUS_CONFIRMATION.FAREWELL.NONE') }}
            </span>
          </span>
        </label>

        <label
          v-for="message in farewellMessages"
          :key="message.id"
          class="flex items-start gap-3 p-3 border rounded-lg cursor-pointer border-n-weak hover:bg-n-alpha-black2"
        >
          <input
            v-model="selectedFarewellId"
            type="radio"
            :value="message.id"
            class="mt-1"
          />
          <span class="flex flex-col gap-1 min-w-0">
            <span class="text-sm font-medium text-n-slate-12 truncate">
              {{ message.short_code }}
            </span>
            <span class="text-sm text-n-slate-11 line-clamp-2">
              {{ farewellPreview(message) }}
            </span>
          </span>
        </label>
      </div>

      <p v-else class="mb-0 text-sm text-n-slate-11">
        {{ t('CONVERSATION.STATUS_CONFIRMATION.FAREWELL.EMPTY') }}
      </p>
    </div>
  </Dialog>
</template>
