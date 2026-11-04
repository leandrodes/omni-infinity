<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';

const route = useRoute();
const { t } = useI18n();

const items = computed(() => [
  {
    name: 'campaigns_whatsapp_index',
    label: t('CAMPAIGN.TYPE_NAV.WHATSAPP_OFFICIAL'),
  },
  {
    name: 'campaigns_unofficial_index',
    label: t('CAMPAIGN.TYPE_NAV.WHATSAPP_UNOFFICIAL'),
  },
  {
    name: 'campaigns_email_index',
    label: t('CAMPAIGN.TYPE_NAV.EMAIL'),
    disabled: true,
  },
  {
    name: 'campaigns_sms_index',
    label: t('CAMPAIGN.TYPE_NAV.SMS'),
  },
]);

const activeName = computed(() => route.name);
</script>

<template>
  <div class="px-6 pt-4">
    <div class="w-full max-w-5xl mx-auto flex flex-wrap gap-2">
      <router-link
        v-for="item in items"
        :key="item.name"
        v-slot="{ navigate }"
        :to="{ name: item.name }"
        custom
      >
        <button
          type="button"
          class="px-4 py-2 text-sm font-medium border rounded-lg transition-colors"
          :class="
            activeName === item.name
              ? 'border-n-brand bg-n-brand text-white'
              : 'border-n-weak bg-n-card text-n-slate-12 hover:bg-n-alpha-2'
          "
          :disabled="item.disabled"
          @click="!item.disabled && navigate()"
        >
          {{ item.label }}
          <span v-if="item.disabled" class="ms-1 text-xs opacity-70">
            {{ t('CAMPAIGN.TYPE_NAV.COMING_SOON') }}
          </span>
        </button>
      </router-link>
    </div>
  </div>
</template>
