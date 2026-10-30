<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import { teamsForAgent } from 'dashboard/helper/assignmentTeamHelper';

const props = defineProps({
  agent: { type: Object, default: null },
  teams: { type: Array, default: () => [] },
  conversationCount: { type: Number, default: 1 },
});

const emit = defineEmits(['confirm', 'close']);
const { t } = useI18n();

const dialogRef = ref(null);
const selectedTeamId = ref(null);
const note = ref('');

const availableTeams = computed(() =>
  teamsForAgent(props.agent, props.teams).sort((a, b) =>
    a.name.localeCompare(b.name)
  )
);

const selectedTeam = computed(() =>
  availableTeams.value.find(team => team.id === selectedTeamId.value)
);

const open = () => {
  selectedTeamId.value = availableTeams.value[0]?.id || null;
  note.value = '';
  dialogRef.value?.open();
};

const close = () => {
  dialogRef.value?.close();
};

const handleClose = () => {
  selectedTeamId.value = null;
  note.value = '';
  emit('close');
};

const handleConfirm = () => {
  if (!selectedTeam.value) return;

  emit('confirm', { team: selectedTeam.value, note: note.value.trim() });
  close();
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="lg"
    :title="t('CONVERSATION.ASSIGNMENT_CONFLICT.TITLE')"
    :confirm-button-label="t('CONVERSATION.ASSIGNMENT_CONFLICT.CONFIRM')"
    :cancel-button-label="t('CONVERSATION.ASSIGNMENT_CONFLICT.CANCEL')"
    :disable-confirm-button="!selectedTeam"
    @confirm="handleConfirm"
    @close="handleClose"
  >
    <div class="flex flex-col gap-4">
      <p class="mb-0 text-sm text-n-slate-11">
        {{
          t('CONVERSATION.ASSIGNMENT_CONFLICT.DESCRIPTION', {
            agentName: agent?.name || '',
            count: conversationCount,
          })
        }}
      </p>
      <label class="flex flex-col gap-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('CONVERSATION.ASSIGNMENT_CONFLICT.TEAM_LABEL') }}
        </span>
        <select
          v-model="selectedTeamId"
          class="w-full px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-solid-2 text-n-slate-12"
        >
          <option
            v-for="team in availableTeams"
            :key="team.id"
            :value="team.id"
          >
            {{ team.name }}
          </option>
        </select>
      </label>
      <p v-if="!availableTeams.length" class="mb-0 text-sm text-n-ruby-11">
        {{ t('CONVERSATION.ASSIGNMENT_CONFLICT.NO_TEAMS') }}
      </p>
      <label class="flex flex-col gap-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('CONVERSATION.ASSIGNMENT_CONFLICT.NOTE_LABEL') }}
        </span>
        <TextArea
          v-model="note"
          :placeholder="t('CONVERSATION.ASSIGNMENT_CONFLICT.NOTE_PLACEHOLDER')"
          class="w-full"
        />
      </label>
    </div>
  </Dialog>
</template>
