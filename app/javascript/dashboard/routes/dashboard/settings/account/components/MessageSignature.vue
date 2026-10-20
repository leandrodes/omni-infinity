<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import SectionLayout from './SectionLayout.vue';
import Switch from 'next/switch/Switch.vue';

const { t } = useI18n();
const { accountId, currentAccount, updateAccount } = useAccount();

const agentsCanDisable = ref(false);

const signatureAgentsCanDisable = computed(
  () => currentAccount.value?.settings?.signature_agents_can_disable === true
);

watch(
  signatureAgentsCanDisable,
  value => {
    agentsCanDisable.value = value;
  },
  { immediate: true }
);

watch(
  () => currentAccount.value?.id || accountId.value,
  id => {
    if (id) agentsCanDisable.value = signatureAgentsCanDisable.value;
  }
);

const toggleSignature = async () => {
  try {
    await updateAccount({
      signature_agents_can_disable: agentsCanDisable.value,
    });
    useAlert(t('GENERAL_SETTINGS.FORM.MESSAGE_SIGNATURE.API.SUCCESS'));
  } catch (error) {
    agentsCanDisable.value = !agentsCanDisable.value;
    useAlert(t('GENERAL_SETTINGS.FORM.MESSAGE_SIGNATURE.API.ERROR'));
  }
};
</script>

<template>
  <SectionLayout
    :title="t('GENERAL_SETTINGS.FORM.MESSAGE_SIGNATURE.TITLE')"
    :description="t('GENERAL_SETTINGS.FORM.MESSAGE_SIGNATURE.NOTE')"
    with-border
  >
    <template #headerActions>
      <div class="flex justify-end">
        <Switch v-model="agentsCanDisable" @change="toggleSignature" />
      </div>
    </template>
  </SectionLayout>
</template>
