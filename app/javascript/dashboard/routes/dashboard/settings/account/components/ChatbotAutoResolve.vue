<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import Editor from 'next/Editor/Editor.vue';
import Switch from 'next/switch/Switch.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import DurationInput from 'next/input/DurationInput.vue';
import { DURATION_UNITS } from 'dashboard/components-next/input/constants';

const { t } = useI18n();
const duration = ref(0);
const unit = ref(DURATION_UNITS.MINUTES);
const message = ref('');
const keywordMessage = ref('');
const keywords = ref('');
const isEnabled = ref(false);
const isSubmitting = ref(false);

const { currentAccount, updateAccount } = useAccount();

watch(
  () => currentAccount.value,
  account => {
    const settings = account?.settings || {};
    duration.value = settings.chatbot_auto_resolve_after;
    message.value = settings.chatbot_auto_resolve_message || '';
    keywordMessage.value =
      settings.chatbot_auto_resolve_keyword_message || '';
    keywords.value = (settings.chatbot_auto_resolve_keywords || []).join(', ');
    if (duration.value) isEnabled.value = true;
  },
  { deep: true, immediate: true }
);

const updateAccountSettings = async settings => {
  try {
    isSubmitting.value = true;
    await updateAccount(settings, { silent: true });
    useAlert(t('CHATBOT_AUTO_RESOLUTION.SAVE.SUCCESS'));
  } catch (error) {
    useAlert(t('CHATBOT_AUTO_RESOLUTION.SAVE.ERROR'));
  } finally {
    isSubmitting.value = false;
  }
};

const handleSubmit = async () => {
  if (duration.value && duration.value < 1) {
    useAlert(t('CHATBOT_AUTO_RESOLUTION.DURATION.ERROR'));
    return Promise.resolve();
  }

  return updateAccountSettings({
    chatbot_auto_resolve_after: duration.value || null,
    chatbot_auto_resolve_message: message.value,
    chatbot_auto_resolve_keywords: keywords.value
      .split(',')
      .map(item => item.trim())
      .filter(Boolean),
    chatbot_auto_resolve_keyword_message: keywordMessage.value,
  });
};

const handleDisable = async () => {
  duration.value = null;
  message.value = '';
  keywords.value = '';
  keywordMessage.value = '';

  return updateAccountSettings({
    chatbot_auto_resolve_after: null,
    chatbot_auto_resolve_message: '',
    chatbot_auto_resolve_keywords: [],
    chatbot_auto_resolve_keyword_message: '',
  });
};

const toggleEnabled = async () => {
  if (!isEnabled.value) await handleDisable();
};
</script>

<template>
  <div
    class="flex flex-col w-full outline-1 outline outline-n-container rounded-xl bg-n-solid-2 divide-y divide-n-weak"
  >
    <div class="flex flex-col gap-2 items-start px-5 py-4">
      <div class="flex justify-between items-center w-full">
        <h3 class="text-heading-2 text-n-slate-12">
          {{ t('CHATBOT_AUTO_RESOLUTION.TITLE') }}
        </h3>
        <div class="flex justify-end">
          <Switch v-model="isEnabled" @change="toggleEnabled" />
        </div>
      </div>
      <p class="mb-0 text-body-para text-n-slate-11">
        {{ t('CHATBOT_AUTO_RESOLUTION.NOTE') }}
      </p>
    </div>

    <div v-if="isEnabled" class="px-5 py-4">
      <form class="grid gap-5" @submit.prevent="handleSubmit">
        <WithLabel
          :label="t('CHATBOT_AUTO_RESOLUTION.DURATION.LABEL')"
          :help-message="t('CHATBOT_AUTO_RESOLUTION.DURATION.HELP')"
        >
          <div class="gap-2 w-full grid grid-cols-[3fr_1fr]">
            <DurationInput
              v-model="duration"
              v-model:unit="unit"
              min="1"
              max="1438560"
              class="w-full"
            />
          </div>
        </WithLabel>
        <WithLabel :label="t('CHATBOT_AUTO_RESOLUTION.MESSAGE.LABEL')">
          <Editor
            v-model="message"
            class="w-full"
            channel-type="Context::NoToolbar"
          />
        </WithLabel>
        <WithLabel :label="t('CHATBOT_AUTO_RESOLUTION.KEYWORDS.LABEL')">
          <input
            v-model="keywords"
            type="text"
            class="w-full border rounded px-3 py-2"
          />
        </WithLabel>
        <WithLabel :label="t('CHATBOT_AUTO_RESOLUTION.KEYWORD_MESSAGE.LABEL')">
          <Editor
            v-model="keywordMessage"
            class="w-full"
            channel-type="Context::NoToolbar"
          />
        </WithLabel>
        <div class="flex gap-2">
          <NextButton
            blue
            type="submit"
            :is-loading="isSubmitting"
            :label="t('CHATBOT_AUTO_RESOLUTION.SAVE.BUTTON')"
          />
        </div>
      </form>
    </div>
  </div>
</template>
