<script setup>
import { computed } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { ATTRIBUTE_TYPES } from './constants';

const props = defineProps({
  attribute: {
    type: Object,
    required: true,
  },
  teams: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['delete', 'toggleTeam', 'toggleAllTeams']);

const iconByType = {
  [ATTRIBUTE_TYPES.TEXT]: 'i-lucide-align-justify',
  [ATTRIBUTE_TYPES.CHECKBOX]: 'i-lucide-circle-check-big',
  [ATTRIBUTE_TYPES.LIST]: 'i-lucide-list',
  [ATTRIBUTE_TYPES.DATE]: 'i-lucide-calendar',
  [ATTRIBUTE_TYPES.LINK]: 'i-lucide-link',
  [ATTRIBUTE_TYPES.NUMBER]: 'i-lucide-hash',
};

const teamIds = computed(() => props.attribute.teamIds || []);

const attributeIcon = computed(() => {
  const typeKey = props.attribute.type?.toLowerCase();
  return iconByType[typeKey] || 'i-lucide-align-justify';
});

const handleDelete = () => {
  emit('delete', props.attribute);
};
</script>

<template>
  <div class="flex justify-between items-center px-4 py-3 w-full">
    <div class="flex gap-3 items-center">
      <h5 class="text-heading-3 text-n-slate-12 line-clamp-1">
        {{ attribute.label }}
      </h5>
      <div class="w-px h-2.5 bg-n-slate-5" />
      <div class="flex gap-1.5 items-center">
        <Icon :icon="attributeIcon" class="size-4 text-n-slate-11" />
        <span class="text-body-para text-n-slate-11">{{ attribute.type }}</span>
      </div>
      <div class="w-px h-2.5 bg-n-slate-5" />
      <div class="flex gap-1.5 items-center">
        <Icon icon="i-lucide-key-round" class="size-4 text-n-slate-11" />
        <span class="text-body-para text-n-slate-11">{{
          attribute.value
        }}</span>
      </div>
    </div>
    <div class="flex flex-wrap items-center gap-2">
      <label class="flex items-center gap-1 text-xs text-n-slate-11">
        <input
          type="checkbox"
          :checked="!teamIds.length"
          @change="emit('toggleAllTeams', attribute, $event.target.checked)"
        />
        {{ $t('CONVERSATION_WORKFLOW.REQUIRED_ATTRIBUTES.TEAMS.ALL') }}
      </label>
      <template v-if="teamIds.length">
        <label
          v-for="team in teams"
          :key="team.id"
          class="flex items-center gap-1 text-xs text-n-slate-11"
        >
          <input
            type="checkbox"
            :checked="teamIds.includes(team.id)"
            @change="emit('toggleTeam', attribute, team.id, $event.target.checked)"
          />
          {{ team.name }}
        </label>
      </template>
    </div>
    <div class="flex gap-2 items-center">
      <Button icon="i-lucide-trash" sm slate ghost @click.stop="handleDelete" />
    </div>
  </div>
</template>
