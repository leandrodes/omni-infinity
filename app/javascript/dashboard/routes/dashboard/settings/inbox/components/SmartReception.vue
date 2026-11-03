<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import SmartReceptionAPI from 'dashboard/api/smartReception';
import SettingsFieldSection from 'dashboard/components-next/Settings/SettingsFieldSection.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  inbox: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();
const store = useStore();
const teams = useMapGetter('teams/getTeams');
const labels = useMapGetter('labels/getLabels');
const activeAgentBot = useMapGetter('agentBots/getActiveAgentBot');

const form = reactive({
  enabled: false,
  name: 'Recepção Inteligente',
  provider: 'openai',
  model: 'gpt-4.1-mini',
  api_key: '',
  api_key_present: false,
  temperature: 0.2,
  max_response_tokens: 500,
  max_history_messages: 20,
  use_previous_conversations: false,
  min_wait_seconds: 5,
  max_wait_seconds: 20,
  primary_prompt: '',
  secondary_prompt: '',
  label_id: '',
  team_id: '',
  read_help_center: false,
});

const providers = ref([]);
const rules = ref([]);
const attachments = ref([]);
const isLoading = ref(true);
const isSaving = ref(false);
const isUploading = ref(false);
const newAttachment = reactive({ file: null, keywords: '', caption: '' });
const attachmentInput = ref(null);
const deleteDialog = ref(null);
const selectedAttachment = ref(null);

const chatbot = computed(() => activeAgentBot.value(props.inbox.id) || {});
const hasChatbot = computed(() => !!chatbot.value.id);
const providerOptions = computed(() =>
  providers.value.map(provider => ({
    value: provider.value,
    label: provider.label,
    disabled: provider.coming_soon,
  }))
);
const currentProvider = computed(() =>
  providers.value.find(provider => provider.value === form.provider)
);
const modelOptions = computed(() => currentProvider.value?.models || []);
const teamOptions = computed(() =>
  (teams.value || []).map(team => ({ value: team.id, label: team.name }))
);
const labelOptions = computed(() =>
  (labels.value || []).map(label => ({ value: label.id, label: label.title }))
);
const temperatureOptions = Array.from({ length: 11 }, (_, index) => index / 10);
const isReadOnly = computed(() => hasChatbot.value);

function addRule() {
  rules.value.push({
    keywords: '',
    action: 'transfer',
    team_id: '',
    label_id: '',
    enabled: true,
  });
}

const setForm = payload => {
  Object.assign(form, {
    enabled: payload.enabled,
    name: payload.name,
    provider: payload.provider,
    model: payload.model,
    api_key: '',
    api_key_present: payload.api_key_present,
    temperature: payload.temperature,
    max_response_tokens: payload.max_response_tokens,
    max_history_messages: payload.max_history_messages,
    use_previous_conversations: payload.use_previous_conversations,
    min_wait_seconds: payload.min_wait_seconds,
    max_wait_seconds: payload.max_wait_seconds,
    primary_prompt: payload.primary_prompt,
    secondary_prompt: payload.secondary_prompt,
    label_id: payload.label_id || '',
    team_id: payload.team_id || '',
    read_help_center: payload.read_help_center,
  });
  rules.value = (payload.keyword_rules || []).map(rule => ({
    keywords: rule.keywords,
    action: rule.action,
    team_id: rule.team_id || '',
    label_id: rule.label_id || '',
    enabled: rule.enabled,
  }));
  if (!rules.value.length) addRule();
  attachments.value = payload.attachments || [];
};

const load = async () => {
  isLoading.value = true;
  try {
    const { data } = await SmartReceptionAPI.show(props.inbox.id);
    providers.value = data.options.providers;
    setForm(data.payload);
  } catch (error) {
    useAlert(
      error?.response?.data?.error || t('INBOX_MGMT.SMART_RECEPTION.LOAD_ERROR')
    );
  } finally {
    isLoading.value = false;
  }
};

const removeRule = index => {
  rules.value.splice(index, 1);
};

const save = async () => {
  isSaving.value = true;
  try {
    const payload = {
      smart_reception_setting: { ...form, api_key: form.api_key || '' },
      keyword_rules: rules.value.filter(rule => rule.keywords.trim()),
    };
    const { data } = await SmartReceptionAPI.update(props.inbox.id, payload);
    setForm(data.payload);
    useAlert(t('INBOX_MGMT.SMART_RECEPTION.SAVED'));
  } catch (error) {
    useAlert(
      error?.response?.data?.error || t('INBOX_MGMT.SMART_RECEPTION.SAVE_ERROR')
    );
  } finally {
    isSaving.value = false;
  }
};

const onProviderChange = () => {
  if (!modelOptions.value.some(model => model.value === form.model)) {
    form.model = modelOptions.value[0]?.value || '';
  }
};

const onAttachmentSelected = event => {
  newAttachment.file = event.target.files?.[0] || null;
};

const uploadAttachment = async () => {
  if (!newAttachment.file || !newAttachment.keywords.trim()) return;

  isUploading.value = true;
  try {
    const { data } = await SmartReceptionAPI.uploadAttachment(props.inbox.id, {
      ...newAttachment,
    });
    attachments.value.push(data.payload);
    Object.assign(newAttachment, { file: null, keywords: '', caption: '' });
    if (attachmentInput.value) attachmentInput.value.value = '';
    useAlert(t('INBOX_MGMT.SMART_RECEPTION.ATTACHMENT_UPLOADED'));
  } catch (error) {
    useAlert(
      error?.response?.data?.error ||
        t('INBOX_MGMT.SMART_RECEPTION.ATTACHMENT_UPLOAD_ERROR')
    );
  } finally {
    isUploading.value = false;
  }
};

const askDeleteAttachment = attachment => {
  selectedAttachment.value = attachment;
  deleteDialog.value?.open();
};

const deleteAttachment = async () => {
  if (!selectedAttachment.value) return;

  try {
    await SmartReceptionAPI.deleteAttachment(
      props.inbox.id,
      selectedAttachment.value.id
    );
    attachments.value = attachments.value.filter(
      item => item.id !== selectedAttachment.value.id
    );
    useAlert(t('INBOX_MGMT.SMART_RECEPTION.ATTACHMENT_DELETED'));
  } catch (error) {
    useAlert(t('INBOX_MGMT.SMART_RECEPTION.ATTACHMENT_DELETE_ERROR'));
  } finally {
    selectedAttachment.value = null;
    deleteDialog.value?.close();
  }
};

watch(
  () => props.inbox.id,
  id => {
    if (id) load();
  },
  { immediate: true }
);

onMounted(() => {
  store.dispatch('teams/get');
  store.dispatch('labels/get');
  store.dispatch('agentBots/fetchAgentBotInbox', props.inbox.id);
});
</script>

<template>
  <div class="max-w-4xl mx-6">
    <div v-if="isLoading" class="flex items-center justify-center py-16">
      <Spinner />
    </div>
    <form v-else class="flex flex-col gap-2" @submit.prevent="save">
      <div
        v-if="hasChatbot"
        class="p-3 mb-2 text-sm border rounded-xl border-n-amber-7 bg-n-amber-2 text-n-amber-11"
      >
        {{ t('INBOX_MGMT.SMART_RECEPTION.CHATBOT_ACTIVE') }}
      </div>

      <div
        class="flex items-center justify-between gap-4 p-4 mb-4 border rounded-xl border-n-weak bg-n-card"
      >
        <div>
          <h3 class="text-heading-3 text-n-slate-12">
            {{ t('INBOX_MGMT.SMART_RECEPTION.ENABLED_LABEL') }}
          </h3>
          <p class="mt-1 text-sm text-n-slate-11">
            {{ t('INBOX_MGMT.SMART_RECEPTION.ENABLED_HELP') }}
          </p>
        </div>
        <Switch
          v-model="form.enabled"
          :class="{ 'opacity-50 pointer-events-none': isReadOnly }"
        />
      </div>

      <SettingsFieldSection :label="t('INBOX_MGMT.SMART_RECEPTION.NAME')">
        <input
          v-model="form.name"
          class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
        />
      </SettingsFieldSection>

      <SettingsFieldSection :label="t('INBOX_MGMT.SMART_RECEPTION.PROVIDER')">
        <select
          v-model="form.provider"
          class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
          @change="onProviderChange"
        >
          <option
            v-for="provider in providerOptions"
            :key="provider.value"
            :value="provider.value"
            :disabled="provider.disabled"
          >
            {{ provider.label
            }}{{
              provider.disabled
                ? ` ${t('INBOX_MGMT.SMART_RECEPTION.COMING_SOON')}`
                : ''
            }}
          </option>
        </select>
      </SettingsFieldSection>

      <SettingsFieldSection :label="t('INBOX_MGMT.SMART_RECEPTION.MODEL')">
        <select
          v-model="form.model"
          class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
        >
          <option
            v-for="model in modelOptions"
            :key="model.value"
            :value="model.value"
          >
            {{ model.label }}
          </option>
        </select>
      </SettingsFieldSection>

      <SettingsFieldSection :label="t('INBOX_MGMT.SMART_RECEPTION.API_KEY')">
        <input
          v-model="form.api_key"
          type="password"
          class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
          :placeholder="
            form.api_key_present
              ? t('INBOX_MGMT.SMART_RECEPTION.API_KEY_KEEP')
              : t('INBOX_MGMT.SMART_RECEPTION.API_KEY_PLACEHOLDER')
          "
        />
      </SettingsFieldSection>

      <details class="mt-4 border rounded-xl border-n-weak bg-n-card">
        <summary
          class="px-4 py-3 text-sm font-medium cursor-pointer text-n-slate-12"
        >
          {{ t('INBOX_MGMT.SMART_RECEPTION.ADVANCED') }}
        </summary>
        <div class="flex flex-col gap-2 px-4 pb-4">
          <SettingsFieldSection
            :label="t('INBOX_MGMT.SMART_RECEPTION.TEMPERATURE')"
            :help-text="t('INBOX_MGMT.SMART_RECEPTION.TEMPERATURE_HELP')"
          >
            <select
              v-model.number="form.temperature"
              class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
            >
              <option
                v-for="value in temperatureOptions"
                :key="value"
                :value="value"
              >
                {{ value.toFixed(1) }}
              </option>
            </select>
            <div
              class="mt-3 overflow-hidden text-xs border rounded-lg border-n-weak"
            >
              <div
                class="grid grid-cols-2 p-2 border-b border-n-weak bg-n-alpha-2"
              >
                <span>{{ t('INBOX_MGMT.SMART_RECEPTION.RANGE_LOW') }}</span>
                <span>{{
                  t('INBOX_MGMT.SMART_RECEPTION.TEMPERATURE_LOW')
                }}</span>
              </div>
              <div class="grid grid-cols-2 p-2 border-b border-n-weak">
                <span>{{ t('INBOX_MGMT.SMART_RECEPTION.RANGE_MEDIUM') }}</span>
                <span>{{
                  t('INBOX_MGMT.SMART_RECEPTION.TEMPERATURE_MEDIUM')
                }}</span>
              </div>
              <div class="grid grid-cols-2 p-2">
                <span>{{ t('INBOX_MGMT.SMART_RECEPTION.RANGE_HIGH') }}</span>
                <span>{{
                  t('INBOX_MGMT.SMART_RECEPTION.TEMPERATURE_HIGH')
                }}</span>
              </div>
            </div>
          </SettingsFieldSection>

          <SettingsFieldSection
            :label="t('INBOX_MGMT.SMART_RECEPTION.MAX_TOKENS')"
          >
            <input
              v-model.number="form.max_response_tokens"
              type="number"
              min="1"
              max="8000"
              class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
            />
          </SettingsFieldSection>

          <SettingsFieldSection
            :label="t('INBOX_MGMT.SMART_RECEPTION.MAX_HISTORY')"
          >
            <input
              v-model.number="form.max_history_messages"
              type="number"
              min="1"
              max="100"
              class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
            />
          </SettingsFieldSection>

          <SettingsFieldSection
            :label="t('INBOX_MGMT.SMART_RECEPTION.PREVIOUS_CONVERSATIONS')"
          >
            <Switch v-model="form.use_previous_conversations" />
          </SettingsFieldSection>

          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <SettingsFieldSection
              :label="t('INBOX_MGMT.SMART_RECEPTION.MIN_WAIT')"
            >
              <input
                v-model.number="form.min_wait_seconds"
                type="number"
                min="0"
                max="300"
                class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
              />
            </SettingsFieldSection>
            <SettingsFieldSection
              :label="t('INBOX_MGMT.SMART_RECEPTION.MAX_WAIT')"
            >
              <input
                v-model.number="form.max_wait_seconds"
                type="number"
                min="0"
                max="600"
                class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
              />
            </SettingsFieldSection>
          </div>

          <SettingsFieldSection
            :label="t('INBOX_MGMT.SMART_RECEPTION.PRIMARY_PROMPT')"
          >
            <textarea
              v-model="form.primary_prompt"
              rows="4"
              class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
            />
          </SettingsFieldSection>

          <SettingsFieldSection
            :label="t('INBOX_MGMT.SMART_RECEPTION.SECONDARY_PROMPT')"
          >
            <textarea
              v-model="form.secondary_prompt"
              rows="3"
              class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
            />
          </SettingsFieldSection>

          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <SettingsFieldSection
              :label="t('INBOX_MGMT.SMART_RECEPTION.DEFAULT_TEAM')"
            >
              <select
                v-model="form.team_id"
                class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
              >
                <option value="">
                  {{ t('INBOX_MGMT.SMART_RECEPTION.NONE') }}
                </option>
                <option
                  v-for="team in teamOptions"
                  :key="team.value"
                  :value="team.value"
                >
                  {{ team.label }}
                </option>
              </select>
            </SettingsFieldSection>
            <SettingsFieldSection
              :label="t('INBOX_MGMT.SMART_RECEPTION.DEFAULT_LABEL')"
            >
              <select
                v-model="form.label_id"
                class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
              >
                <option value="">
                  {{ t('INBOX_MGMT.SMART_RECEPTION.NONE') }}
                </option>
                <option
                  v-for="label in labelOptions"
                  :key="label.value"
                  :value="label.value"
                >
                  {{ label.label }}
                </option>
              </select>
            </SettingsFieldSection>
          </div>

          <SettingsFieldSection
            :label="t('INBOX_MGMT.SMART_RECEPTION.READ_HELP_CENTER')"
            :help-text="t('INBOX_MGMT.SMART_RECEPTION.READ_HELP_CENTER_HELP')"
          >
            <Switch v-model="form.read_help_center" />
          </SettingsFieldSection>
        </div>
      </details>

      <section class="p-4 mt-4 border rounded-xl border-n-weak bg-n-card">
        <div class="flex items-start justify-between gap-4">
          <div>
            <h3 class="text-heading-3 text-n-slate-12">
              {{ t('INBOX_MGMT.SMART_RECEPTION.KEYWORDS_TITLE') }}
            </h3>
            <p class="mt-1 text-sm text-n-slate-11">
              {{ t('INBOX_MGMT.SMART_RECEPTION.KEYWORDS_HELP') }}
            </p>
          </div>
          <NextButton
            type="button"
            xs
            faded
            blue
            icon="i-lucide-plus"
            :label="t('INBOX_MGMT.SMART_RECEPTION.ADD_RULE')"
            @click="addRule"
          />
        </div>

        <div v-if="rules.length" class="flex flex-col gap-3 mt-4">
          <div
            v-for="(rule, index) in rules"
            :key="index"
            class="flex flex-col gap-3 p-3 border rounded-lg border-n-weak"
          >
            <div class="flex items-start gap-2">
              <input
                v-model="rule.keywords"
                class="flex-1 min-w-0 px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
                :placeholder="
                  t('INBOX_MGMT.SMART_RECEPTION.KEYWORDS_PLACEHOLDER')
                "
              />
              <NextButton
                type="button"
                ruby
                faded
                sm
                icon="i-lucide-trash"
                @click="removeRule(index)"
              />
            </div>
            <div class="grid grid-cols-1 gap-2 md:grid-cols-3">
              <select
                v-model="rule.action"
                class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
              >
                <option value="transfer">
                  {{ t('INBOX_MGMT.SMART_RECEPTION.TRANSFER') }}
                </option>
                <option value="resolve">
                  {{ t('INBOX_MGMT.SMART_RECEPTION.RESOLVE') }}
                </option>
              </select>
              <select
                v-if="rule.action === 'transfer'"
                v-model="rule.team_id"
                class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
              >
                <option value="">
                  {{ t('INBOX_MGMT.SMART_RECEPTION.TEAM') }}
                </option>
                <option
                  v-for="team in teamOptions"
                  :key="team.value"
                  :value="team.value"
                >
                  {{ team.label }}
                </option>
              </select>
              <select
                v-model="rule.label_id"
                class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
              >
                <option value="">
                  {{ t('INBOX_MGMT.SMART_RECEPTION.LABEL') }}
                </option>
                <option
                  v-for="label in labelOptions"
                  :key="label.value"
                  :value="label.value"
                >
                  {{ label.label }}
                </option>
              </select>
            </div>
          </div>
        </div>
      </section>

      <section class="p-4 mt-4 border rounded-xl border-n-weak bg-n-card">
        <h3 class="text-heading-3 text-n-slate-12">
          {{ t('INBOX_MGMT.SMART_RECEPTION.ATTACHMENTS_TITLE') }}
        </h3>
        <p class="mt-1 text-sm text-n-slate-11">
          {{ t('INBOX_MGMT.SMART_RECEPTION.ATTACHMENTS_HELP') }}
        </p>

        <div class="flex flex-col gap-3 mt-4">
          <input
            ref="attachmentInput"
            type="file"
            class="w-full text-sm text-n-slate-11"
            @change="onAttachmentSelected"
          />
          <div class="grid grid-cols-1 gap-2 md:grid-cols-3">
            <input
              v-model="newAttachment.keywords"
              class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
              :placeholder="
                t('INBOX_MGMT.SMART_RECEPTION.KEYWORDS_PLACEHOLDER')
              "
            />
            <input
              v-model="newAttachment.caption"
              class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
              :placeholder="t('INBOX_MGMT.SMART_RECEPTION.CAPTION')"
            />
            <NextButton
              type="button"
              sm
              :is-loading="isUploading"
              :disabled="!newAttachment.file || !newAttachment.keywords"
              icon="i-lucide-upload"
              :label="t('INBOX_MGMT.SMART_RECEPTION.ATTACH')"
              @click="uploadAttachment"
            />
          </div>
        </div>

        <ul v-if="attachments.length" class="flex flex-col gap-2 mt-4">
          <li
            v-for="attachment in attachments"
            :key="attachment.id"
            class="flex items-center justify-between gap-3 p-2 border rounded-lg border-n-weak"
          >
            <div class="min-w-0">
              <p class="text-sm font-medium truncate text-n-slate-12">
                {{ attachment.filename }}
              </p>
              <p class="text-xs text-n-slate-11">
                {{ attachment.keywords }}
                <template v-if="attachment.caption">
                  {{ t('INBOX_MGMT.SMART_RECEPTION.SEPARATOR') }}
                  {{ attachment.caption }}
                </template>
              </p>
            </div>
            <NextButton
              type="button"
              ghost
              ruby
              sm
              icon="i-lucide-trash"
              @click="askDeleteAttachment(attachment)"
            />
          </li>
        </ul>
      </section>

      <div class="flex justify-end mt-6">
        <NextButton
          type="submit"
          :is-loading="isSaving"
          :disabled="isReadOnly"
          :label="t('INBOX_MGMT.SMART_RECEPTION.SAVE')"
        />
      </div>
    </form>

    <Dialog
      ref="deleteDialog"
      type="alert"
      :title="t('INBOX_MGMT.SMART_RECEPTION.ATTACHMENT_DELETE_TITLE')"
      :description="
        t('INBOX_MGMT.SMART_RECEPTION.ATTACHMENT_DELETE_DESCRIPTION')
      "
      :confirm-button-label="t('INBOX_MGMT.SMART_RECEPTION.CONFIRM_DELETE')"
      :cancel-button-label="t('INBOX_MGMT.SMART_RECEPTION.CANCEL')"
      @confirm="deleteAttachment"
    />
  </div>
</template>
