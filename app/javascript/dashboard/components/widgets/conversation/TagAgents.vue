<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStoreGetters } from 'dashboard/composables/store';
import Avatar from 'next/avatar/Avatar.vue';
import CaretAnchoredPicker from 'dashboard/components-next/preview-picker/CaretAnchoredPicker.vue';

const props = defineProps({
  caretPosition: { type: Object, default: null },
  searchKey: { type: String, default: '' },
});

const emit = defineEmits(['selectAgent', 'close', 'removeTrigger']);

const { t } = useI18n();
const getters = useStoreGetters();
const agents = computed(() => getters['agents/getVerifiedAgents'].value);
const searchQuery = ref(props.searchKey);
const searchTerm = computed(() => searchQuery.value.trim().toLowerCase());
const matchesSearch = name => name?.toLowerCase().includes(searchTerm.value);

const items = computed(() =>
  agents.value
    .filter(agent => matchesSearch(agent.name))
    .map(agent => ({
      id: `user-${agent.id}`,
      record: { ...agent, type: 'user', displayName: agent.name },
      label: agent.name,
      title: agent.name,
      subtitle: agent.email,
    }))
);

const availabilityLabels = computed(() => ({
  online: t('PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.ONLINE'),
  busy: t('PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.BUSY'),
  offline: t('PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.OFFLINE'),
}));

const availabilityLabel = status => availabilityLabels.value[status] ?? '';
const onSelect = item => emit('selectAgent', item.record);
</script>

<template>
  <CaretAnchoredPicker
    v-model:search="searchQuery"
    :caret-position="caretPosition"
    :items="items"
    :search-placeholder="t('CONVERSATION.PICKER.MENTION.SEARCH_PLACEHOLDER')"
    :empty-label="t('COMBOBOX.EMPTY_STATE')"
    @select="onSelect"
    @close="emit('close')"
    @remove-trigger="emit('removeTrigger')"
  >
    <template #leading="{ item }">
      <Avatar
        :src="item.record.thumbnail"
        :name="item.label"
        :size="24"
        rounded-full
        class="flex-shrink-0"
      />
    </template>
    <template #preview="{ item }">
      <div v-if="item" class="flex flex-col gap-3 px-4 py-3">
        <div class="flex items-start gap-3">
          <Avatar
            :src="item.record.thumbnail"
            :name="item.label"
            :size="40"
            :status="item.record.availability_status"
            rounded-full
            class="flex-shrink-0"
          />
          <div class="flex flex-col min-w-0 gap-0.5">
            <span class="text-sm font-medium truncate text-n-slate-12">
              {{ item.label }}
            </span>
            <span
              v-if="item.subtitle"
              class="text-xs break-words text-n-slate-11"
            >
              {{ item.subtitle }}
            </span>
          </div>
        </div>
        <div class="flex flex-col gap-2 text-xs">
          <div class="flex items-center justify-between gap-2">
            <span class="text-n-slate-10">
              {{ t('CONVERSATION.PICKER.MENTION.AVAILABILITY') }}
            </span>
            <span class="capitalize text-n-slate-12">
              {{ availabilityLabel(item.record.availability_status) }}
            </span>
          </div>
          <div class="flex items-center justify-between gap-2">
            <span class="text-n-slate-10">
              {{ t('CONVERSATION.PICKER.MENTION.ROLE') }}
            </span>
            <span class="capitalize text-n-slate-12">{{
              item.record.role
            }}</span>
          </div>
        </div>
      </div>
    </template>
  </CaretAnchoredPicker>
</template>
