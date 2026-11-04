<script setup>
import { useI18n } from 'vue-i18n';
import CampaignLayout from 'dashboard/components-next/Campaigns/CampaignLayout.vue';

const { t } = useI18n();
</script>

<template>
  <CampaignLayout
    :header-title="t('CAMPAIGN.EMAIL.HEADER_TITLE')"
    :button-label="t('CAMPAIGN.EMAIL.NEW_CAMPAIGN')"
  >
    <div class="py-20 text-center text-n-slate-11">
      <p class="text-base text-n-slate-12">
        {{ t('CAMPAIGN.EMAIL.COMING_SOON_TITLE') }}
      </p>
      <p class="mt-2 text-sm">
        {{ t('CAMPAIGN.EMAIL.COMING_SOON_DESCRIPTION') }}
      </p>
    </div>
  </CampaignLayout>
</template>
