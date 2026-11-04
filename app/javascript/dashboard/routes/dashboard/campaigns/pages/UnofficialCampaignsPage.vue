<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import UnofficialCampaignsAPI from 'dashboard/api/unofficialCampaigns';
import CampaignLayout from 'dashboard/components-next/Campaigns/CampaignLayout.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import UnofficialCampaignWizard from 'dashboard/components-next/Campaigns/Pages/CampaignPage/UnofficialCampaign/UnofficialCampaignWizard.vue';

const { t } = useI18n();
const store = useStore();
const campaigns = ref([]);
const isLoading = ref(false);
const showWizard = ref(false);
const optOutWords = ref('');
const optOutDialog = ref(null);
const riskDialog = ref(null);
const deleteDialog = ref(null);
const selectedCampaign = ref(null);

const uiFlags = useMapGetter('inboxes/getUIFlags');
const inboxes = useMapGetter('inboxes/getInboxes');
const unofficialInboxes = computed(() =>
  (inboxes.value || []).filter(
    inbox => inbox.channel_type === 'Channel::UnofficialWhatsapp'
  )
);

const loadCampaigns = async () => {
  isLoading.value = true;
  try {
    const { data } = await UnofficialCampaignsAPI.get();
    campaigns.value = data.payload || [];
  } catch (error) {
    useAlert(t('CAMPAIGN.UNOFFICIAL.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const openRisk = () => riskDialog.value?.open();
const nextAfterRisk = () => {
  riskDialog.value?.close();
  showWizard.value = true;
};

const openOptOut = async () => {
  try {
    const { data } = await UnofficialCampaignsAPI.getOptOutWords();
    optOutWords.value = (data.words || []).join(', ');
    optOutDialog.value?.open();
  } catch {
    useAlert(t('CAMPAIGN.UNOFFICIAL.OPT_OUT.LOAD_ERROR'));
  }
};

const saveOptOut = async () => {
  try {
    await UnofficialCampaignsAPI.updateOptOutWords(
      optOutWords.value
        .split(',')
        .map(word => word.trim())
        .filter(Boolean)
    );
    optOutDialog.value?.close();
    useAlert(t('CAMPAIGN.UNOFFICIAL.OPT_OUT.SAVED'));
  } catch {
    useAlert(t('CAMPAIGN.UNOFFICIAL.OPT_OUT.SAVE_ERROR'));
  }
};

const askDelete = campaign => {
  selectedCampaign.value = campaign;
  deleteDialog.value?.open();
};

const confirmDelete = async () => {
  try {
    await UnofficialCampaignsAPI.delete(selectedCampaign.value.id);
    deleteDialog.value?.close();
    await loadCampaigns();
  } catch {
    useAlert(t('CAMPAIGN.UNOFFICIAL.DELETE_ERROR'));
  }
};

const statusLabel = status =>
  t(`CAMPAIGN.UNOFFICIAL.STATUS.${status.toUpperCase()}`);

const progress = campaign => {
  if (!campaign.total_contacts) return 0;
  return Math.round((campaign.sent_contacts / campaign.total_contacts) * 100);
};

const downloadTemplate = async () => {
  try {
    const { data } = await UnofficialCampaignsAPI.downloadTemplate();
    const url = URL.createObjectURL(data);
    const link = document.createElement('a');
    link.href = url;
    link.download = 'modelo-campanha-whatsapp-nao-oficial.csv';
    link.click();
    URL.revokeObjectURL(url);
  } catch {
    useAlert(t('CAMPAIGN.UNOFFICIAL.TEMPLATE_ERROR'));
  }
};

onMounted(() => {
  store.dispatch('inboxes/get');
  loadCampaigns();
});
</script>

<template>
  <CampaignLayout
    :header-title="t('CAMPAIGN.UNOFFICIAL.HEADER_TITLE')"
    :button-label="t('CAMPAIGN.UNOFFICIAL.NEW_CAMPAIGN')"
    @click="openRisk"
  >
    <div class="flex flex-wrap items-center justify-between gap-3 mb-4">
      <p class="text-sm text-n-slate-11">
        {{ t('CAMPAIGN.UNOFFICIAL.DESCRIPTION') }}
      </p>
      <div class="flex gap-2">
        <NextButton
          ghost
          slate
          sm
          icon="i-lucide-shield-check"
          :label="t('CAMPAIGN.UNOFFICIAL.OPT_OUT.CONFIGURE')"
          @click="openOptOut"
        />
        <NextButton
          ghost
          slate
          sm
          icon="i-lucide-download"
          :label="t('CAMPAIGN.UNOFFICIAL.TEMPLATE')"
          @click="downloadTemplate"
        />
      </div>
    </div>

    <div v-if="isLoading" class="py-16 text-center text-n-slate-11">
      {{ t('CAMPAIGN.UNOFFICIAL.LOADING') }}
    </div>
    <div v-else-if="campaigns.length" class="flex flex-col gap-3">
      <article
        v-for="campaign in campaigns"
        :key="campaign.id"
        class="p-4 border rounded-xl border-n-weak bg-n-card"
      >
        <div class="flex items-start justify-between gap-4">
          <div>
            <h3 class="text-base font-medium text-n-slate-12">
              {{ campaign.title }}
            </h3>
            <p class="mt-1 text-sm text-n-slate-11">
              {{ statusLabel(campaign.status) }} ·
              {{ campaign.sent_contacts }}/{{ campaign.total_contacts }}
              {{ t('CAMPAIGN.UNOFFICIAL.CONTACTS') }}
            </p>
          </div>
          <NextButton
            ghost
            ruby
            sm
            icon="i-lucide-trash"
            @click="askDelete(campaign)"
          />
        </div>
        <div class="w-full h-2 mt-4 overflow-hidden rounded-full bg-n-slate-3">
          <div
            class="h-full rounded-full bg-n-brand"
            :style="{ width: `${progress(campaign)}%` }"
          />
        </div>
      </article>
    </div>
    <div v-else class="py-20 text-center text-n-slate-11">
      <p class="text-base text-n-slate-12">
        {{ t('CAMPAIGN.UNOFFICIAL.EMPTY_TITLE') }}
      </p>
      <p class="mt-2 text-sm">
        {{ t('CAMPAIGN.UNOFFICIAL.EMPTY_DESCRIPTION') }}
      </p>
    </div>

    <Dialog
      ref="riskDialog"
      type="alert"
      :title="t('CAMPAIGN.UNOFFICIAL.RISK.TITLE')"
      :description="t('CAMPAIGN.UNOFFICIAL.RISK.DESCRIPTION')"
      :confirm-button-label="t('CAMPAIGN.UNOFFICIAL.RISK.CONFIRM')"
      :cancel-button-label="t('CAMPAIGN.UNOFFICIAL.RISK.CANCEL')"
      @confirm="nextAfterRisk"
    />

    <Dialog
      ref="optOutDialog"
      type="edit"
      :title="t('CAMPAIGN.UNOFFICIAL.OPT_OUT.TITLE')"
      :description="t('CAMPAIGN.UNOFFICIAL.OPT_OUT.DESCRIPTION')"
      :confirm-button-label="t('CAMPAIGN.UNOFFICIAL.OPT_OUT.SAVE')"
      @confirm="saveOptOut"
    >
      <textarea
        v-model="optOutWords"
        rows="3"
        class="w-full px-3 py-2 text-sm border rounded-lg reset-base border-n-weak bg-n-alpha-black2 text-n-slate-12"
        :placeholder="t('CAMPAIGN.UNOFFICIAL.OPT_OUT.PLACEHOLDER')"
      />
    </Dialog>

    <Dialog
      ref="deleteDialog"
      type="alert"
      :title="t('CAMPAIGN.UNOFFICIAL.DELETE_TITLE')"
      :description="t('CAMPAIGN.UNOFFICIAL.DELETE_DESCRIPTION')"
      :confirm-button-label="t('CAMPAIGN.UNOFFICIAL.DELETE_CONFIRM')"
      :cancel-button-label="t('CAMPAIGN.UNOFFICIAL.CANCEL')"
      @confirm="confirmDelete"
    />

    <Teleport to="body">
      <div
        v-if="showWizard"
        class="fixed inset-0 z-50 flex items-start justify-center p-4 overflow-y-auto bg-black/50"
      >
        <div class="w-full max-w-4xl my-8">
          <UnofficialCampaignWizard
            :inboxes="unofficialInboxes"
            :is-loading-inboxes="uiFlags.isFetching"
            @close="showWizard = false"
            @created="
              showWizard = false;
              loadCampaigns();
            "
          />
        </div>
      </div>
    </Teleport>
  </CampaignLayout>
</template>
