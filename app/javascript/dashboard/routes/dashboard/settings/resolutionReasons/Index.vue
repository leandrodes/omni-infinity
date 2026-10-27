<script setup>
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import ConversationRequiredAttributes from 'dashboard/components-next/ConversationWorkflow/ConversationRequiredAttributes.vue';
</script>

<template>
  <SettingsLayout :no-records-found="false" class="gap-10">
    <template #header>
      <BaseSettingsHeader
        :title="$t('RESOLUTION_REASONS.INDEX.HEADER.TITLE')"
        :description="$t('RESOLUTION_REASONS.INDEX.HEADER.DESCRIPTION')"
        feature-name="conversation-workflow"
      />
    </template>

    <template #body>
      <div class="flex flex-col gap-6 mt-4">
        <ConversationRequiredAttributes :is-enabled="true" />
      </div>
    </template>
  </SettingsLayout>
</template>
