<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import ContactAPI from 'dashboard/api/contacts';
import UnofficialCampaignsAPI from 'dashboard/api/unofficialCampaigns';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';

defineProps({
  inboxes: { type: Array, default: () => [] },
  isLoadingInboxes: { type: Boolean, default: false },
});

const emit = defineEmits(['close', 'created']);

const { t } = useI18n();
const store = useStore();
const teams = useMapGetter('teams/getTeams');
const agents = useMapGetter('agents/getAgents');

const steps = computed(() => [
  t('CAMPAIGN.UNOFFICIAL.STEPS.CAMPAIGN'),
  t('CAMPAIGN.UNOFFICIAL.STEPS.MESSAGES'),
  t('CAMPAIGN.UNOFFICIAL.STEPS.CONTACTS'),
  t('CAMPAIGN.UNOFFICIAL.STEPS.PACING'),
  t('CAMPAIGN.UNOFFICIAL.STEPS.FINISH'),
]);

const step = ref(1);
const isSaving = ref(false);

const form = reactive({
  title: '',
  senderInboxIds: [],
  startMode: 'immediate',
  scheduledAt: '',
  minContactIntervalSeconds: 30,
  maxContactIntervalSeconds: 90,
  pauseEnabled: false,
  pauseEveryMinContacts: 10,
  pauseEveryMaxContacts: 20,
  pauseMinMinutes: 10,
  pauseMaxMinutes: 20,
  allowedDays: [1, 2, 3, 4, 5],
  allowedStartTime: '08:00',
  allowedEndTime: '18:00',
  postAction: 'pending_team',
  postTeamId: '',
  postAgentId: '',
});

const messages = ref([
  {
    waitMinSeconds: 3,
    waitMaxSeconds: 8,
    variants: [
      { content: '', files: [] },
      { content: '', files: [] },
      { content: '', files: [] },
    ],
  },
]);

const selectedContacts = ref([]);
const contactQuery = ref('');
const contactResults = ref([]);
const isSearchingContacts = ref(false);
const importFile = ref(null);

const dayOptions = [
  { value: 0, label: 'Domingo' },
  { value: 1, label: 'Segunda' },
  { value: 2, label: 'Terça' },
  { value: 3, label: 'Quarta' },
  { value: 4, label: 'Quinta' },
  { value: 5, label: 'Sexta' },
  { value: 6, label: 'Sábado' },
];

const teamOptions = computed(() =>
  (teams.value || []).map(team => ({ value: team.id, label: team.name }))
);
const agentOptions = computed(() =>
  (agents.value || [])
    .filter(agent => agent.confirmed)
    .map(agent => ({ value: agent.id, label: agent.name }))
);

const currentInboxIds = computed(() => form.senderInboxIds.map(Number));
const canGoBack = computed(() => step.value > 1 && !isSaving.value);

const toggleInbox = id => {
  const value = Number(id);
  form.senderInboxIds = currentInboxIds.value.includes(value)
    ? form.senderInboxIds.filter(item => Number(item) !== value)
    : [...form.senderInboxIds, value];
};

const addMessage = () => {
  messages.value.push({
    waitMinSeconds: 3,
    waitMaxSeconds: 8,
    variants: [
      { content: '', files: [] },
      { content: '', files: [] },
      { content: '', files: [] },
    ],
  });
};

const removeMessage = index => {
  if (messages.value.length === 1) return;
  messages.value.splice(index, 1);
};

const onFilesSelected = (event, messageIndex, variantIndex) => {
  messages.value[messageIndex].variants[variantIndex].files = Array.from(
    event.target.files || []
  );
};

const searchContacts = async () => {
  if (!contactQuery.value.trim()) return;

  isSearchingContacts.value = true;
  try {
    const { data } = await ContactAPI.search(contactQuery.value.trim(), 1);
    contactResults.value = (data.payload || []).filter(
      contact => !contact.campaign_opt_out
    );
  } catch {
    useAlert(t('CAMPAIGN.UNOFFICIAL.CONTACTS.SEARCH_ERROR'));
  } finally {
    isSearchingContacts.value = false;
  }
};

const isContactSelected = id =>
  selectedContacts.value.some(contact => contact.id === id);

const toggleContact = contact => {
  if (isContactSelected(contact.id)) {
    selectedContacts.value = selectedContacts.value.filter(
      item => item.id !== contact.id
    );
  } else {
    selectedContacts.value.push(contact);
  }
};

const removeContact = id => {
  selectedContacts.value = selectedContacts.value.filter(
    contact => contact.id !== id
  );
};

const onImportFile = event => {
  importFile.value = event.target.files?.[0] || null;
};

const toggleDay = day => {
  form.allowedDays = form.allowedDays.includes(day)
    ? form.allowedDays.filter(value => value !== day)
    : [...form.allowedDays, day];
};

const timeToMinutes = value => {
  const [hour = 0, minute = 0] = value.split(':').map(Number);
  return hour * 60 + minute;
};

const validateStep = () => {
  if (step.value === 1) {
    if (!form.title.trim()) return t('CAMPAIGN.UNOFFICIAL.VALIDATION.TITLE');
    if (!form.senderInboxIds.length) {
      return t('CAMPAIGN.UNOFFICIAL.VALIDATION.SENDERS');
    }
    if (form.startMode === 'scheduled' && !form.scheduledAt) {
      return t('CAMPAIGN.UNOFFICIAL.VALIDATION.SCHEDULED_AT');
    }
  }
  if (step.value === 2) {
    const invalid = messages.value.some(
      message =>
        message.variants.length !== 3 ||
        message.variants.some(variant => !variant.content.trim())
    );
    if (invalid) return t('CAMPAIGN.UNOFFICIAL.VALIDATION.VARIANTS');
  }
  if (step.value === 3 && !selectedContacts.value.length && !importFile.value) {
    return t('CAMPAIGN.UNOFFICIAL.VALIDATION.CONTACTS');
  }
  if (step.value === 4) {
    if (form.minContactIntervalSeconds > form.maxContactIntervalSeconds) {
      return t('CAMPAIGN.UNOFFICIAL.VALIDATION.INTERVALS');
    }
    if (!form.allowedDays.length) {
      return t('CAMPAIGN.UNOFFICIAL.VALIDATION.DAYS');
    }
    if (
      timeToMinutes(form.allowedStartTime) >= timeToMinutes(form.allowedEndTime)
    ) {
      return t('CAMPAIGN.UNOFFICIAL.VALIDATION.WINDOW');
    }
    if (
      form.pauseEnabled &&
      form.pauseEveryMinContacts > form.pauseEveryMaxContacts
    ) {
      return t('CAMPAIGN.UNOFFICIAL.VALIDATION.PAUSE_INTERVALS');
    }
  }
  if (step.value === 5) {
    if (form.postAction !== 'resolve' && !form.postTeamId) {
      return t('CAMPAIGN.UNOFFICIAL.VALIDATION.TEAM');
    }
    if (form.postAction === 'assign_team_agent' && !form.postAgentId) {
      return t('CAMPAIGN.UNOFFICIAL.VALIDATION.AGENT');
    }
  }
  return '';
};

const next = () => {
  const error = validateStep();
  if (error) {
    useAlert(error);
    return;
  }
  step.value += 1;
};

const back = () => {
  if (step.value > 1) step.value -= 1;
};

const buildCampaign = () => ({
  title: form.title,
  sender_inbox_ids: form.senderInboxIds.map(Number),
  start_mode: form.startMode,
  scheduled_at: form.startMode === 'scheduled' ? form.scheduledAt : null,
  min_contact_interval_seconds: Number(form.minContactIntervalSeconds),
  max_contact_interval_seconds: Number(form.maxContactIntervalSeconds),
  pause_enabled: form.pauseEnabled,
  pause_every_min_contacts: Number(form.pauseEveryMinContacts),
  pause_every_max_contacts: Number(form.pauseEveryMaxContacts),
  pause_min_minutes: Number(form.pauseMinMinutes),
  pause_max_minutes: Number(form.pauseMaxMinutes),
  allowed_days: form.allowedDays,
  allowed_start_minute: timeToMinutes(form.allowedStartTime),
  allowed_end_minute: timeToMinutes(form.allowedEndTime),
  post_action: form.postAction,
  post_team_id: form.postTeamId || null,
  post_agent_id: form.postAgentId || null,
  contact_ids: selectedContacts.value.map(contact => contact.id),
  messages: messages.value.map(message => ({
    wait_min_seconds: Number(message.waitMinSeconds),
    wait_max_seconds: Number(message.waitMaxSeconds),
    variants: message.variants.map(variant => ({ content: variant.content })),
  })),
});

const save = async () => {
  const error = validateStep();
  if (error) {
    useAlert(error);
    return;
  }

  const formData = new FormData();
  formData.append('campaign', JSON.stringify(buildCampaign()));
  if (importFile.value) formData.append('contacts_file', importFile.value);

  messages.value.forEach((message, messageIndex) => {
    message.variants.forEach((variant, variantIndex) => {
      variant.files.forEach(file => {
        formData.append(
          `variant_files[${messageIndex}][${variantIndex}][]`,
          file
        );
      });
    });
  });

  isSaving.value = true;
  try {
    await UnofficialCampaignsAPI.createCampaign(formData);
    useAlert(t('CAMPAIGN.UNOFFICIAL.CREATED'));
    emit('created');
  } catch (errorResponse) {
    useAlert(
      errorResponse?.response?.data?.error ||
        t('CAMPAIGN.UNOFFICIAL.CREATE_ERROR')
    );
  } finally {
    isSaving.value = false;
  }
};

onMounted(() => {
  store.dispatch('teams/get');
  store.dispatch('agents/get');
});
</script>

<template>
  <div
    class="overflow-hidden bg-n-surface-1 border rounded-2xl border-n-weak shadow-xl"
  >
    <header
      class="flex items-center justify-between gap-4 px-6 py-4 border-b border-n-weak"
    >
      <div>
        <h2 class="text-heading-1 text-n-slate-12">
          {{ t('CAMPAIGN.UNOFFICIAL.WIZARD_TITLE') }}
        </h2>
        <p class="mt-1 text-sm text-n-slate-11">
          {{
            t('CAMPAIGN.UNOFFICIAL.STEP', {
              current: step,
              total: steps.length,
            })
          }}
          · {{ steps[step - 1] }}
        </p>
      </div>
      <NextButton ghost slate sm icon="i-lucide-x" @click="$emit('close')" />
    </header>

    <div class="flex gap-1 px-6 pt-4">
      <div
        v-for="(label, index) in steps"
        :key="label"
        class="h-1 flex-1 rounded-full"
        :class="index + 1 <= step ? 'bg-n-brand' : 'bg-n-slate-3'"
      />
    </div>

    <main class="max-h-[70vh] overflow-y-auto px-6 py-5">
      <div v-if="step === 1" class="flex flex-col gap-4">
        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium text-n-slate-12">{{
            t('CAMPAIGN.UNOFFICIAL.FORM.TITLE')
          }}</span>
          <input
            v-model="form.title"
            class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
          />
        </label>

        <div class="flex flex-col gap-2">
          <span class="text-sm font-medium text-n-slate-12">{{
            t('CAMPAIGN.UNOFFICIAL.FORM.SENDERS')
          }}</span>
          <div v-if="isLoadingInboxes" class="text-sm text-n-slate-11">
            {{ t('CAMPAIGN.UNOFFICIAL.FORM.LOADING_SENDERS') }}
          </div>
          <div
            v-else-if="inboxes.length"
            class="grid grid-cols-1 gap-2 md:grid-cols-2"
          >
            <label
              v-for="inbox in inboxes"
              :key="inbox.id"
              class="flex items-center gap-2 p-3 border rounded-lg cursor-pointer border-n-weak hover:bg-n-alpha-2"
            >
              <input
                type="checkbox"
                :checked="currentInboxIds.includes(Number(inbox.id))"
                @change="toggleInbox(inbox.id)"
              />
              <span class="text-sm text-n-slate-12">{{ inbox.name }}</span>
            </label>
          </div>
          <p v-else class="text-sm text-n-slate-11">
            {{ t('CAMPAIGN.UNOFFICIAL.FORM.NO_SENDERS') }}
          </p>
        </div>

        <div class="grid grid-cols-1 gap-3 md:grid-cols-2">
          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium text-n-slate-12">{{
              t('CAMPAIGN.UNOFFICIAL.FORM.START_MODE')
            }}</span>
            <select
              v-model="form.startMode"
              class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
            >
              <option value="immediate">
                {{ t('CAMPAIGN.UNOFFICIAL.FORM.START_NOW') }}
              </option>
              <option value="scheduled">
                {{ t('CAMPAIGN.UNOFFICIAL.FORM.SCHEDULED') }}
              </option>
            </select>
          </label>
          <label
            v-if="form.startMode === 'scheduled'"
            class="flex flex-col gap-1"
          >
            <span class="text-sm font-medium text-n-slate-12">{{
              t('CAMPAIGN.UNOFFICIAL.FORM.SCHEDULED_AT')
            }}</span>
            <input
              v-model="form.scheduledAt"
              type="datetime-local"
              class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
            />
          </label>
        </div>
      </div>

      <div v-else-if="step === 2" class="flex flex-col gap-4">
        <article
          v-for="(message, messageIndex) in messages"
          :key="messageIndex"
          class="p-4 border rounded-xl border-n-weak bg-n-card"
        >
          <div class="flex items-center justify-between gap-3">
            <h3 class="text-heading-3 text-n-slate-12">
              {{
                t('CAMPAIGN.UNOFFICIAL.FORM.MESSAGE', {
                  number: messageIndex + 1,
                })
              }}
            </h3>
            <NextButton
              v-if="messages.length > 1"
              ghost
              ruby
              sm
              icon="i-lucide-trash"
              @click="removeMessage(messageIndex)"
            />
          </div>
          <div class="grid grid-cols-1 gap-3 mt-3 md:grid-cols-2">
            <label class="flex flex-col gap-1">
              <span class="text-sm text-n-slate-12">{{
                t('CAMPAIGN.UNOFFICIAL.FORM.WAIT_MIN')
              }}</span>
              <input
                v-model.number="message.waitMinSeconds"
                type="number"
                min="3"
                max="8"
                class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
              />
            </label>
            <label class="flex flex-col gap-1">
              <span class="text-sm text-n-slate-12">{{
                t('CAMPAIGN.UNOFFICIAL.FORM.WAIT_MAX')
              }}</span>
              <input
                v-model.number="message.waitMaxSeconds"
                type="number"
                min="3"
                max="8"
                class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
              />
            </label>
          </div>
          <div class="grid grid-cols-1 gap-3 mt-3 lg:grid-cols-3">
            <div
              v-for="(variant, variantIndex) in message.variants"
              :key="variantIndex"
              class="flex flex-col gap-2 p-3 border rounded-lg border-n-weak"
            >
              <span class="text-sm font-medium text-n-slate-12">
                {{
                  t('CAMPAIGN.UNOFFICIAL.FORM.VERSION', {
                    number: variantIndex + 1,
                  })
                }}
              </span>
              <textarea
                v-model="variant.content"
                rows="5"
                class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
              />
              <input
                type="file"
                multiple
                class="text-xs text-n-slate-11"
                @change="onFilesSelected($event, messageIndex, variantIndex)"
              />
            </div>
          </div>
        </article>
        <NextButton
          type="button"
          faded
          blue
          sm
          icon="i-lucide-plus"
          :label="t('CAMPAIGN.UNOFFICIAL.FORM.ADD_MESSAGE')"
          @click="addMessage"
        />
      </div>

      <div v-else-if="step === 3" class="flex flex-col gap-5">
        <div class="flex flex-col gap-2">
          <span class="text-sm font-medium text-n-slate-12">{{
            t('CAMPAIGN.UNOFFICIAL.FORM.SEARCH_CONTACTS')
          }}</span>
          <div class="flex gap-2">
            <input
              v-model="contactQuery"
              class="flex-1 px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
              :placeholder="t('CAMPAIGN.UNOFFICIAL.FORM.SEARCH_PLACEHOLDER')"
              @keyup.enter="searchContacts"
            />
            <NextButton
              type="button"
              sm
              :is-loading="isSearchingContacts"
              :label="t('CAMPAIGN.UNOFFICIAL.FORM.SEARCH')"
              @click="searchContacts"
            />
          </div>
          <div
            v-if="contactResults.length"
            class="grid grid-cols-1 gap-2 md:grid-cols-2"
          >
            <label
              v-for="contact in contactResults"
              :key="contact.id"
              class="flex items-center gap-2 p-2 border rounded-lg cursor-pointer border-n-weak hover:bg-n-alpha-2"
            >
              <input
                type="checkbox"
                :checked="isContactSelected(contact.id)"
                @change="toggleContact(contact)"
              />
              <span class="min-w-0 text-sm truncate text-n-slate-12">
                {{ `${contact.name} · ${contact.phone_number}` }}
              </span>
            </label>
          </div>
        </div>

        <div class="flex flex-col gap-2">
          <span class="text-sm font-medium text-n-slate-12">{{
            t('CAMPAIGN.UNOFFICIAL.FORM.SELECTED_CONTACTS', {
              count: selectedContacts.length,
            })
          }}</span>
          <div v-if="selectedContacts.length" class="flex flex-wrap gap-2">
            <span
              v-for="contact in selectedContacts"
              :key="contact.id"
              class="inline-flex items-center gap-1 px-2 py-1 text-xs rounded-lg bg-n-alpha-3 text-n-slate-12"
            >
              {{ contact.name }}
              <button type="button" @click="removeContact(contact.id)">
                {{ t('CAMPAIGN.UNOFFICIAL.FORM.REMOVE') }}
              </button>
            </span>
          </div>
          <p v-else class="text-sm text-n-slate-11">
            {{ t('CAMPAIGN.UNOFFICIAL.FORM.NO_CONTACTS') }}
          </p>
        </div>

        <div class="p-4 border rounded-xl border-n-weak bg-n-card">
          <p class="mb-2 text-sm font-medium text-n-slate-12">
            {{ t('CAMPAIGN.UNOFFICIAL.FORM.IMPORT') }}
          </p>
          <input
            type="file"
            accept=".csv,.xlsx"
            class="text-sm text-n-slate-11"
            @change="onImportFile"
          />
          <p class="mt-2 text-xs text-n-slate-11">
            {{ t('CAMPAIGN.UNOFFICIAL.FORM.IMPORT_HELP') }}
          </p>
        </div>
      </div>

      <div v-else-if="step === 4" class="flex flex-col gap-5">
        <div class="grid grid-cols-1 gap-3 md:grid-cols-2">
          <label class="flex flex-col gap-1">
            <span class="text-sm text-n-slate-12">{{
              t('CAMPAIGN.UNOFFICIAL.FORM.MIN_CONTACT_INTERVAL')
            }}</span>
            <input
              v-model.number="form.minContactIntervalSeconds"
              type="number"
              min="0"
              class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
            />
          </label>
          <label class="flex flex-col gap-1">
            <span class="text-sm text-n-slate-12">{{
              t('CAMPAIGN.UNOFFICIAL.FORM.MAX_CONTACT_INTERVAL')
            }}</span>
            <input
              v-model.number="form.maxContactIntervalSeconds"
              type="number"
              min="0"
              class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
            />
          </label>
        </div>

        <div class="p-4 border rounded-xl border-n-weak bg-n-card">
          <div class="flex items-center justify-between gap-3">
            <div>
              <p class="text-sm font-medium text-n-slate-12">
                {{ t('CAMPAIGN.UNOFFICIAL.FORM.PAUSE_ENABLED') }}
              </p>
              <p class="text-xs text-n-slate-11">
                {{ t('CAMPAIGN.UNOFFICIAL.FORM.PAUSE_HELP') }}
              </p>
            </div>
            <Switch v-model="form.pauseEnabled" />
          </div>
          <div
            v-if="form.pauseEnabled"
            class="grid grid-cols-1 gap-3 mt-4 md:grid-cols-2"
          >
            <label class="flex flex-col gap-1">
              <span class="text-sm text-n-slate-12">{{
                t('CAMPAIGN.UNOFFICIAL.FORM.PAUSE_EVERY_MIN')
              }}</span>
              <input
                v-model.number="form.pauseEveryMinContacts"
                type="number"
                min="1"
                class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
              />
            </label>
            <label class="flex flex-col gap-1">
              <span class="text-sm text-n-slate-12">{{
                t('CAMPAIGN.UNOFFICIAL.FORM.PAUSE_EVERY_MAX')
              }}</span>
              <input
                v-model.number="form.pauseEveryMaxContacts"
                type="number"
                min="1"
                class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
              />
            </label>
            <label class="flex flex-col gap-1">
              <span class="text-sm text-n-slate-12">{{
                t('CAMPAIGN.UNOFFICIAL.FORM.PAUSE_MIN')
              }}</span>
              <input
                v-model.number="form.pauseMinMinutes"
                type="number"
                min="1"
                class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
              />
            </label>
            <label class="flex flex-col gap-1">
              <span class="text-sm text-n-slate-12">{{
                t('CAMPAIGN.UNOFFICIAL.FORM.PAUSE_MAX')
              }}</span>
              <input
                v-model.number="form.pauseMaxMinutes"
                type="number"
                min="1"
                class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
              />
            </label>
          </div>
        </div>

        <div class="flex flex-col gap-2">
          <span class="text-sm font-medium text-n-slate-12">{{
            t('CAMPAIGN.UNOFFICIAL.FORM.ALLOWED_DAYS')
          }}</span>
          <div class="flex flex-wrap gap-2">
            <label
              v-for="day in dayOptions"
              :key="day.value"
              class="flex items-center gap-1 px-3 py-2 text-sm border rounded-lg cursor-pointer border-n-weak"
            >
              <input
                type="checkbox"
                :checked="form.allowedDays.includes(day.value)"
                @change="toggleDay(day.value)"
              />
              {{ day.label }}
            </label>
          </div>
        </div>

        <div class="grid grid-cols-1 gap-3 md:grid-cols-2">
          <label class="flex flex-col gap-1">
            <span class="text-sm text-n-slate-12">{{
              t('CAMPAIGN.UNOFFICIAL.FORM.ALLOWED_START')
            }}</span>
            <input
              v-model="form.allowedStartTime"
              type="time"
              class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
            />
          </label>
          <label class="flex flex-col gap-1">
            <span class="text-sm text-n-slate-12">{{
              t('CAMPAIGN.UNOFFICIAL.FORM.ALLOWED_END')
            }}</span>
            <input
              v-model="form.allowedEndTime"
              type="time"
              class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
            />
          </label>
        </div>
      </div>

      <div v-else class="flex flex-col gap-4">
        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium text-n-slate-12">{{
            t('CAMPAIGN.UNOFFICIAL.FORM.POST_ACTION')
          }}</span>
          <select
            v-model="form.postAction"
            class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
          >
            <option value="pending_team">
              {{ t('CAMPAIGN.UNOFFICIAL.FORM.POST_PENDING_TEAM') }}
            </option>
            <option value="assign_team">
              {{ t('CAMPAIGN.UNOFFICIAL.FORM.POST_ASSIGN_TEAM') }}
            </option>
            <option value="assign_team_agent">
              {{ t('CAMPAIGN.UNOFFICIAL.FORM.POST_ASSIGN_TEAM_AGENT') }}
            </option>
            <option value="resolve">
              {{ t('CAMPAIGN.UNOFFICIAL.FORM.POST_RESOLVE') }}
            </option>
          </select>
        </label>
        <label v-if="form.postAction !== 'resolve'" class="flex flex-col gap-1">
          <span class="text-sm font-medium text-n-slate-12">{{
            t('CAMPAIGN.UNOFFICIAL.FORM.TEAM')
          }}</span>
          <select
            v-model="form.postTeamId"
            class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
          >
            <option value="">{{ t('CAMPAIGN.UNOFFICIAL.FORM.SELECT') }}</option>
            <option
              v-for="team in teamOptions"
              :key="team.value"
              :value="team.value"
            >
              {{ team.label }}
            </option>
          </select>
        </label>
        <label
          v-if="form.postAction === 'assign_team_agent'"
          class="flex flex-col gap-1"
        >
          <span class="text-sm font-medium text-n-slate-12">{{
            t('CAMPAIGN.UNOFFICIAL.FORM.AGENT')
          }}</span>
          <select
            v-model="form.postAgentId"
            class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
          >
            <option value="">{{ t('CAMPAIGN.UNOFFICIAL.FORM.SELECT') }}</option>
            <option
              v-for="agent in agentOptions"
              :key="agent.value"
              :value="agent.value"
            >
              {{ agent.label }}
            </option>
          </select>
        </label>

        <div
          class="p-4 text-sm border rounded-xl border-n-weak bg-n-card text-n-slate-11"
        >
          <p>
            {{ t('CAMPAIGN.UNOFFICIAL.SUMMARY.NAME') }}:
            <strong class="text-n-slate-12">{{ form.title }}</strong>
          </p>
          <p class="mt-1">
            {{ t('CAMPAIGN.UNOFFICIAL.SUMMARY.SENDERS') }}:
            {{ form.senderInboxIds.length }}
          </p>
          <p class="mt-1">
            {{ t('CAMPAIGN.UNOFFICIAL.SUMMARY.CONTACTS') }}:
            {{ selectedContacts.length
            }}{{
              importFile
                ? ` + ${t('CAMPAIGN.UNOFFICIAL.SUMMARY.IMPORTED_FILE')}`
                : ''
            }}
          </p>
        </div>
      </div>
    </main>

    <footer
      class="flex items-center justify-between gap-3 px-6 py-4 border-t border-n-weak"
    >
      <NextButton
        type="button"
        faded
        slate
        :label="t('CAMPAIGN.UNOFFICIAL.CANCEL')"
        @click="$emit('close')"
      />
      <div class="flex gap-2">
        <NextButton
          v-if="canGoBack"
          type="button"
          faded
          blue
          :label="t('CAMPAIGN.UNOFFICIAL.BACK')"
          @click="back"
        />
        <NextButton
          v-if="step < steps.length"
          type="button"
          :label="t('CAMPAIGN.UNOFFICIAL.NEXT')"
          @click="next"
        />
        <NextButton
          v-else
          type="button"
          :is-loading="isSaving"
          :label="t('CAMPAIGN.UNOFFICIAL.SAVE')"
          @click="save"
        />
      </div>
    </footer>
  </div>
</template>
