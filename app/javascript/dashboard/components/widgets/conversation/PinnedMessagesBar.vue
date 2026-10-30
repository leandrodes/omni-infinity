<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { useAlert } from 'dashboard/composables';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
});

const { t } = useI18n();
const store = useStore();
const getPinnedMessages = useMapGetter('getPinnedMessages');

const messages = computed(() => getPinnedMessages.value(props.conversationId));

const preview = message => {
  const content = message.content || '';
  return content.length > 90 ? `${content.slice(0, 90)}...` : content;
};

const scrollToMessage = message => {
  emitter.emit(BUS_EVENTS.SCROLL_TO_MESSAGE, { messageId: message.id });
};

const unpin = async message => {
  try {
    await store.dispatch('unpinMessage', {
      conversationId: props.conversationId,
      messageId: message.id,
    });
  } catch {
    useAlert(t('CONVERSATION.PINNED.UNPIN_ERROR'));
  }
};
</script>

<template>
  <div
    v-if="messages.length"
    class="flex flex-col gap-1 px-4 py-2 border-b bg-n-surface-1 border-n-weak"
  >
    <div class="flex items-center gap-2 text-xs font-medium text-n-slate-11">
      <span>{{ t('CONVERSATION.PINNED.TITLE') }}</span>
      <span class="text-n-slate-10">({{ messages.length }})</span>
    </div>
    <div class="flex gap-2 overflow-x-auto">
      <button
        v-for="message in messages"
        :key="message.id"
        type="button"
        class="flex items-center gap-2 max-w-sm px-2 py-1 text-xs text-left border rounded-md border-n-weak bg-n-alpha-1 hover:bg-n-alpha-2"
        @click="scrollToMessage(message)"
      >
        <span class="truncate text-n-slate-12">{{ preview(message) }}</span>
        <span
          role="button"
          tabindex="0"
          class="text-n-slate-10 hover:text-n-ruby-11"
          :aria-label="t('CONVERSATION.PINNED.UNPIN')"
          @click.stop="unpin(message)"
          @keydown.enter.stop="unpin(message)"
        >
          <Icon icon="i-lucide-x" class="size-3" />
        </span>
      </button>
    </div>
  </div>
</template>
