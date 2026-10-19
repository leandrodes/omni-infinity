<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import SectionLayout from './SectionLayout.vue';
import Switch from 'next/switch/Switch.vue';
import NextInput from 'next/input/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import TranscriptionSettingsAPI from 'dashboard/api/transcriptionSettings';

const { t } = useI18n();
const { accountId, currentAccount, updateAccount } = useAccount();

const isEnabled = ref(false);
const isLoading = ref(false);
const isSaving = ref(false);

const provider = ref('system');
const endpoint = ref('');
const model = ref('');
const language = ref('');
const apiKey = ref('');
const apiKeyPresent = ref(false);
const allowSystem = ref(false);
const systemConfigured = ref(false);

const providerOptions = computed(() => [
  {
    value: 'system',
    label: t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.PROVIDER.SYSTEM'),
    disabled: false,
  },
  {
    value: 'external',
    label: t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.PROVIDER.EXTERNAL'),
    disabled: false,
  },
]);

const showFields = computed(() => provider.value === 'external');
const systemBlocked = computed(
  () => provider.value === 'system' && !allowSystem.value
);

const applyData = data => {
  isEnabled.value = !!data.enabled;
  provider.value = data.provider || 'system';
  endpoint.value = data.endpoint || '';
  model.value = data.model || '';
  language.value = data.language || '';
  apiKey.value = '';
  apiKeyPresent.value = !!data.api_key_present;
  allowSystem.value = !!data.allow_system;
  systemConfigured.value = !!data.system_configured;
};

const loadSettings = async () => {
  isLoading.value = true;
  try {
    const { data } = await TranscriptionSettingsAPI.getSettings();
    applyData(data);
  } catch (error) {
    // Ignore: keep defaults
  } finally {
    isLoading.value = false;
  }
};

watch(
  () => currentAccount.value?.id || accountId.value,
  id => {
    if (id) loadSettings();
  },
  { immediate: true }
);

const toggleAudioTranscription = async () => {
  try {
    await updateAccount({ audio_transcriptions: isEnabled.value });
    useAlert(t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.API.SUCCESS'));
  } catch (error) {
    isEnabled.value = !isEnabled.value;
    useAlert(t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.API.ERROR'));
  }
};

const saveSettings = async () => {
  isSaving.value = true;
  try {
    const payload = { provider: provider.value };
    if (provider.value === 'external') {
      payload.endpoint = endpoint.value;
      payload.model = model.value;
      payload.language = language.value;
      if (apiKey.value) payload.api_key = apiKey.value;
    }
    const { data } = await TranscriptionSettingsAPI.updateSettings(payload);
    applyData(data);
    useAlert(t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.SAVE.SUCCESS'));
  } catch (error) {
    useAlert(t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.SAVE.ERROR'));
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <SectionLayout
    :title="t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.TITLE')"
    :description="t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.NOTE')"
    with-border
  >
    <template #headerActions>
      <div class="flex justify-end">
        <Switch v-model="isEnabled" @change="toggleAudioTranscription" />
      </div>
    </template>

    <div v-if="isEnabled" class="grid gap-4 mt-2">
      <div>
        <label class="block mb-1 text-sm font-medium text-n-slate-12">
          {{ t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.PROVIDER.LABEL') }}
        </label>
        <select v-model="provider" class="!mb-0 text-sm w-full">
          <option
            v-for="option in providerOptions"
            :key="option.value"
            :value="option.value"
          >
            {{ option.label }}
          </option>
        </select>
      </div>

      <p
        v-if="systemBlocked"
        class="text-sm font-medium text-n-ruby-11"
      >
        {{
          t(
            'GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.PROVIDER.SYSTEM_NOT_ALLOWED'
          )
        }}
      </p>

      <template v-if="showFields">
        <div>
          <label class="block mb-1 text-sm font-medium text-n-slate-12">
            {{ t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.ENDPOINT.LABEL') }}
          </label>
          <NextInput
            v-model="endpoint"
            type="text"
            class="w-full"
            :placeholder="
              t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.ENDPOINT.PLACEHOLDER')
            "
          />
          <p class="mt-1 text-xs text-n-slate-11">
            {{ t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.ENDPOINT.HELP') }}
          </p>
        </div>
        <div>
          <label class="block mb-1 text-sm font-medium text-n-slate-12">
            {{ t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.MODEL.LABEL') }}
          </label>
          <NextInput
            v-model="model"
            type="text"
            class="w-full"
            :placeholder="
              t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.MODEL.PLACEHOLDER')
            "
          />
        </div>
        <div>
          <label class="block mb-1 text-sm font-medium text-n-slate-12">
            {{ t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.LANGUAGE.LABEL') }}
          </label>
          <NextInput
            v-model="language"
            type="text"
            class="w-full"
            :placeholder="
              t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.LANGUAGE.PLACEHOLDER')
            "
          />
        </div>
        <div>
          <label class="block mb-1 text-sm font-medium text-n-slate-12">
            {{ t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.API_KEY.LABEL') }}
          </label>
          <NextInput
            v-model="apiKey"
            type="password"
            class="w-full"
            :placeholder="
              apiKeyPresent
                ? t(
                    'GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.API_KEY.PLACEHOLDER_KEEP'
                  )
                : t(
                    'GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.API_KEY.PLACEHOLDER'
                  )
            "
          />
        </div>
      </template>

      <div>
        <NextButton
          blue
          :is-loading="isSaving"
          :disabled="isLoading"
          @click="saveSettings"
        >
          {{ t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.SAVE.LABEL') }}
        </NextButton>
      </div>
    </div>
  </SectionLayout>
</template>
