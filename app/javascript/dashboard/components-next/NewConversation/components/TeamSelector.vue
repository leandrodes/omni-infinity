<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { vOnClickOutside } from '@vueuse/components';

import Button from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

const props = defineProps({
  teams: {
    type: Array,
    default: () => [],
  },
  targetTeam: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['updateTeam']);

const { t } = useI18n();
const isDropdownOpen = ref(false);

const teamMenuItems = computed(() =>
  props.teams.map(team => ({
    label: team.name,
    value: team.id,
    action: 'team',
  }))
);

const handleTeamAction = ({ value }) => {
  const team = props.teams.find(item => item.id === value) || null;
  emit('updateTeam', team);
  isDropdownOpen.value = false;
};
</script>

<template>
  <div
    class="flex items-center flex-1 w-full gap-3 px-4 py-3 overflow-y-visible"
  >
    <label class="mb-0.5 text-sm font-medium text-n-slate-11 whitespace-nowrap">
      {{ t('COMPOSE_NEW_CONVERSATION.FORM.TEAM_SELECTOR.LABEL') }}
    </label>
    <div
      v-if="targetTeam"
      class="flex items-center gap-1.5 rounded-md bg-n-alpha-2 truncate ltr:pl-3 rtl:pr-3 ltr:pr-1 rtl:pl-1 h-7 min-w-0"
    >
      <span class="text-sm truncate text-n-slate-12">
        {{ targetTeam.name }}
      </span>
      <Button
        variant="ghost"
        icon="i-lucide-x"
        color="slate"
        size="xs"
        class="flex-shrink-0"
        @click="emit('updateTeam', null)"
      />
    </div>
    <div
      v-else
      v-on-click-outside="() => (isDropdownOpen = false)"
      class="relative flex items-center h-7"
    >
      <Button
        :label="t('COMPOSE_NEW_CONVERSATION.FORM.TEAM_SELECTOR.BUTTON')"
        variant="link"
        size="sm"
        color="slate"
        class="hover:!no-underline"
        @click="isDropdownOpen = !isDropdownOpen"
      />
      <DropdownMenu
        v-if="teamMenuItems.length > 0 && isDropdownOpen"
        :menu-items="teamMenuItems"
        class="ltr:left-0 rtl:right-0 z-[100] top-8 max-h-56 w-fit max-w-sm dark:!outline-n-slate-5"
        @action="handleTeamAction"
      />
    </div>
  </div>
</template>
