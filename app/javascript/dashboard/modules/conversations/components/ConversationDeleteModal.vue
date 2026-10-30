<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import Popover from 'dashboard/components-next/popover/Popover.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  isAConversationRoute,
  isAInboxViewRoute,
  getConversationDashboardRoute,
} from 'dashboard/helper/routeHelpers';

const props = defineProps({
  conversation: { type: Object, required: true },
});

const emit = defineEmits(['close', 'deleted']);

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const router = useRouter();
const isDeleting = ref(false);

const confirmMessage = computed(() =>
  t('CONVERSATION.DELETE_CONVERSATION.DESCRIPTION', {
    conversationId: props.conversation.id,
  })
);

const onDelete = async hide => {
  try {
    isDeleting.value = true;
    await store.dispatch('deleteConversation', props.conversation.id);
    useAlert(t('CONVERSATION.SUCCESS_DELETE_CONVERSATION'));
    hide();
    emit('deleted');
    emit('close');

    if (isAConversationRoute(route.name)) {
      router.push({ name: getConversationDashboardRoute(route.name) });
    } else if (isAInboxViewRoute(route.name)) {
      router.push({ name: 'inbox_view' });
    }
  } catch {
    useAlert(t('CONVERSATION.FAIL_DELETE_CONVERSATION'));
  } finally {
    isDeleting.value = false;
  }
};
</script>

<template>
  <Popover @hide="$emit('close')">
    <slot name="trigger" />
    <template #content="{ hide }">
      <div class="w-full md:w-80 p-6 flex flex-col gap-4">
        <div class="flex flex-col gap-2">
          <h3 class="text-base font-medium leading-6 text-n-slate-12">
            {{ $t('CONVERSATION.DELETE_CONVERSATION.TITLE') }}
          </h3>
          <p class="mb-0 text-sm text-n-slate-11">
            {{ confirmMessage }}
          </p>
        </div>
        <div class="flex items-center justify-end gap-2">
          <Button
            faded
            slate
            sm
            :label="$t('CONVERSATION.DELETE_CONVERSATION.CANCEL')"
            @click="hide"
          />
          <Button
            ruby
            sm
            :label="$t('CONVERSATION.DELETE_CONVERSATION.CONFIRM')"
            :is-loading="isDeleting"
            :disabled="isDeleting"
            @click="onDelete(hide)"
          />
        </div>
      </div>
    </template>
  </Popover>
</template>
