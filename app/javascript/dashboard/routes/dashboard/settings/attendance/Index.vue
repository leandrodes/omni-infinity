<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import SectionLayout from '../account/components/SectionLayout.vue';
import Switch from 'next/switch/Switch.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();
const { accountId, currentAccount, updateAccount } = useAccount();

const defaultSettings = {
  enable_chatbot_conversations_filter: false,
  enable_resolved_conversations_filter: false,
  show_inbox_name_in_conversation_list: false,
  list_only_last_resolved_conversation_per_contact: false,
  hide_conversations_assigned_to_others: false,
  hide_resolved_conversations_assigned_to_others: false,
  show_conversations_only_from_user_teams: false,
  signature_agents_can_disable: false,
  agents_can_reopen_conversations: false,
  agents_can_join_conversations_as_participant: false,
  ignore_whatsapp_groups: false,
  enable_whatsapp_groups_filter: false,
  allow_create_whatsapp_groups: false,
  allow_end_whatsapp_groups: false,
  allow_transfer_whatsapp_groups: false,
  reactions_appear_as_response: false,
};

const settings = ref({ ...defaultSettings });

const syncSettings = () => {
  const accountSettings = currentAccount.value?.settings || {};
  Object.keys(defaultSettings).forEach(key => {
    settings.value[key] = accountSettings[key] === true;
  });
};

watch(() => currentAccount.value?.id, syncSettings, { immediate: true });

const saveSettings = async () => {
  try {
    await updateAccount(settings.value);
    useAlert(t('ATTENDANCE_SETTINGS.SAVE.SUCCESS'));
  } catch (error) {
    useAlert(t('ATTENDANCE_SETTINGS.SAVE.ERROR'));
  }
};
</script>

<template>
  <div class="flex flex-col w-full max-w-2xl ltr:mr-auto rtl:ml-auto">
    <div class="flex flex-col gap-4">
      <SectionLayout
        :title="t('ATTENDANCE_SETTINGS.DISPLAY.TITLE')"
        :description="t('ATTENDANCE_SETTINGS.DISPLAY.NOTE')"
        with-border
      >
        <div class="flex flex-col gap-4">
          <div v-for="key in ['enable_chatbot_conversations_filter','enable_resolved_conversations_filter','show_inbox_name_in_conversation_list','list_only_last_resolved_conversation_per_contact']" :key="key" class="flex items-center justify-between gap-4">
            <span class="text-sm">{{ t(`ATTENDANCE_SETTINGS.DISPLAY.${key.toUpperCase()}`) }}</span>
            <Switch v-model="settings[key]" />
          </div>
        </div>
      </SectionLayout>

      <SectionLayout
        :title="t('ATTENDANCE_SETTINGS.VISIBILITY.TITLE')"
        :description="t('ATTENDANCE_SETTINGS.VISIBILITY.NOTE')"
        with-border
      >
        <div class="flex flex-col gap-4">
          <div v-for="key in ['hide_conversations_assigned_to_others','hide_resolved_conversations_assigned_to_others','show_conversations_only_from_user_teams']" :key="key" class="flex items-center justify-between gap-4">
            <span class="text-sm">{{ t(`ATTENDANCE_SETTINGS.VISIBILITY.${key.toUpperCase()}`) }}</span>
            <Switch v-model="settings[key]" />
          </div>
        </div>
      </SectionLayout>

      <SectionLayout
        :title="t('ATTENDANCE_SETTINGS.PERMISSIONS.TITLE')"
        :description="t('ATTENDANCE_SETTINGS.PERMISSIONS.NOTE')"
        with-border
      >
        <div class="flex flex-col gap-4">
          <div v-for="key in ['signature_agents_can_disable','agents_can_reopen_conversations','agents_can_join_conversations_as_participant']" :key="key" class="flex items-center justify-between gap-4">
            <span class="text-sm">{{ t(`ATTENDANCE_SETTINGS.PERMISSIONS.${key.toUpperCase()}`) }}</span>
            <Switch v-model="settings[key]" />
          </div>
        </div>
      </SectionLayout>

      <SectionLayout
        :title="t('ATTENDANCE_SETTINGS.GROUPS.TITLE')"
        :description="t('ATTENDANCE_SETTINGS.GROUPS.NOTE')"
        with-border
      >
        <div class="flex flex-col gap-4">
          <div v-for="key in ['ignore_whatsapp_groups','enable_whatsapp_groups_filter','allow_create_whatsapp_groups','allow_end_whatsapp_groups','allow_transfer_whatsapp_groups']" :key="key" class="flex items-center justify-between gap-4">
            <span class="text-sm">{{ t(`ATTENDANCE_SETTINGS.GROUPS.${key.toUpperCase()}`) }}</span>
            <Switch v-model="settings[key]" />
          </div>
        </div>
      </SectionLayout>

      <SectionLayout
        :title="t('ATTENDANCE_SETTINGS.OTHERS.TITLE')"
        :description="t('ATTENDANCE_SETTINGS.OTHERS.NOTE')"
        with-border
      >
        <div class="flex flex-col gap-4">
          <div class="flex items-center justify-between gap-4">
            <span class="text-sm">{{ t('ATTENDANCE_SETTINGS.OTHERS.REACTIONS_APPEAR_AS_RESPONSE') }}</span>
            <Switch v-model="settings.reactions_appear_as_response" />
          </div>
        </div>
      </SectionLayout>

      <div>
        <NextButton blue @click="saveSettings">
          {{ t('ATTENDANCE_SETTINGS.SAVE.BUTTON') }}
        </NextButton>
      </div>
    </div>
  </div>
</template>
