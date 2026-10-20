<script setup>
import { computed, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Input from 'dashboard/components-next/input/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  channel: { type: Object, required: true },
});

const emit = defineEmits(['back', 'created']);

const { t } = useI18n();
const store = useStore();

// Per-channel field list + payload shape, mirroring the standalone Telegram
// settings form. Labels/placeholders reuse the existing INBOX_MGMT translations
// so there's nothing new to localize.
const FORMS = {
  telegram: {
    fields: [
      {
        key: 'botToken',
        label: t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.BOT_TOKEN.LABEL'),
        placeholder: t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.BOT_TOKEN.PLACEHOLDER'),
        type: 'password',
      },
    ],
    errorMessage: t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.API.ERROR_MESSAGE'),
    buildPayload: values => ({
      channel: { type: 'telegram', bot_token: values.botToken },
    }),
  },
};

const config = FORMS[props.channel.type];
const values = reactive(
  Object.fromEntries(config.fields.map(field => [field.key, '']))
);
const isCreating = ref(false);

const isValid = computed(() =>
  config.fields.every(field => values[field.key].trim())
);

const submit = async () => {
  if (!isValid.value || isCreating.value) return;

  isCreating.value = true;
  try {
    await store.dispatch('inboxes/createChannel', config.buildPayload(values));
    emit('created');
  } catch (error) {
    useAlert(error?.message || config.errorMessage);
  } finally {
    isCreating.value = false;
  }
};
</script>

<!-- This sits inside the dialog's <form>; intercept Enter so it submits the
  channel here instead of bubbling up and completing onboarding. -->
<template>
  <div class="flex flex-col gap-4" @keydown.enter.prevent="submit">
    <div class="grid grid-cols-[auto_1fr] items-center gap-4">
      <template v-for="field in config.fields" :key="field.key">
        <label :for="field.key" class="text-sm font-medium text-n-slate-12">
          {{ field.label }}
        </label>
        <Input
          :id="field.key"
          v-model="values[field.key]"
          :type="field.type || 'text'"
          :placeholder="field.placeholder"
        />
      </template>
    </div>
    <div class="flex items-center gap-3">
      <NextButton
        type="button"
        slate
        faded
        class="flex-1 justify-center"
        :label="t('ONBOARDING_INBOX_SETUP.CHANNELS_DIALOG.BACK')"
        @click="emit('back')"
      />
      <NextButton
        type="button"
        blue
        class="flex-1 justify-center"
        :is-loading="isCreating"
        :disabled="!isValid"
        :label="t('ONBOARDING_INBOX_SETUP.CHANNELS_DIALOG.CONNECT')"
        @click="submit"
      />
    </div>
  </div>
</template>
