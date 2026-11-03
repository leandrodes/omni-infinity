<script setup>
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useBranding } from 'shared/composables/useBranding';
import { picoSearch } from '@chatwoot/pico-search';
import IntegrationItem from './IntegrationItem.vue';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';

const store = useStore();
const getters = useStoreGetters();
const { t } = useI18n();
const { currentAccount } = useAccount();
const { replaceInstallationName } = useBranding();

const searchQuery = ref('');
const uiFlags = getters['integrations/getUIFlags'];

const copilotEnabled = computed(
  () => !!currentAccount.value?.features?.saas_ai_copilot
);

const transcriptionItem = computed(() => ({
  id: 'transcription',
  name: t('INTEGRATION_SETTINGS.TRANSCRIPTION.TITLE'),
  description: t('INTEGRATION_SETTINGS.TRANSCRIPTION.DESCRIPTION'),
  enabled: !!currentAccount.value?.audio_transcriptions,
}));

const integrationList = computed(() => [
  ...getters['integrations/getAppIntegrations'].value,
  transcriptionItem.value,
]);

const filteredIntegrationList = computed(() => {
  const query = searchQuery.value.trim();
  if (!query) return integrationList.value;
  return picoSearch(integrationList.value, query, ['name', 'description']);
});

onMounted(() => {
  store.dispatch('integrations/get');
});
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="$t('INTEGRATION_SETTINGS.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        v-model:search-query="searchQuery"
        :title="$t('INTEGRATION_SETTINGS.HEADER')"
        :description="
          replaceInstallationName($t('INTEGRATION_SETTINGS.DESCRIPTION'))
        "
        :link-text="$t('INTEGRATION_SETTINGS.LEARN_MORE')"
        :search-placeholder="$t('INTEGRATION_SETTINGS.SEARCH_PLACEHOLDER')"
        feature-name="integrations"
      />
    </template>
    <template #body>
      <div class="flex-grow flex-shrink overflow-auto">
        <span
          v-if="!filteredIntegrationList.length && searchQuery"
          class="flex-1 flex items-center justify-center py-20 text-center text-body-main !text-base text-n-slate-11"
        >
          {{ $t('INTEGRATION_SETTINGS.NO_RESULTS') }}
        </span>
        <div
          v-else
          class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4"
        >
          <IntegrationItem
            v-for="item in filteredIntegrationList"
            :id="item.id"
            :key="item.id"
            :logo="item.logo"
            :name="item.name"
            :description="item.description"
            :enabled="
              item.id === 'openai' && !copilotEnabled ? false : item.enabled
            "
            :disabled="item.id === 'openai' && !copilotEnabled"
          />
        </div>
      </div>
    </template>
  </SettingsLayout>
</template>
