<script setup>
import { useI18n } from 'vue-i18n';
import AudioTranscription from 'dashboard/routes/dashboard/settings/account/components/AudioTranscription.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';

const { t } = useI18n();
</script>

<template>
  <SettingsLayout>
    <template #header>
      <BaseSettingsHeader
        :title="t('INTEGRATION_SETTINGS.TRANSCRIPTION.TITLE')"
        :description="t('INTEGRATION_SETTINGS.TRANSCRIPTION.DESCRIPTION')"
        :back-button-label="t('INTEGRATION_SETTINGS.HEADER')"
        feature-name="transcription"
      />
    </template>
    <template #body>
      <AudioTranscription embedded />
    </template>
  </SettingsLayout>
</template>
