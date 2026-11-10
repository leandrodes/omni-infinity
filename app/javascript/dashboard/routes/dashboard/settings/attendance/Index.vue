<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import SectionLayout from '../account/components/SectionLayout.vue';
import Switch from 'next/switch/Switch.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();
const { currentAccount, updateAccount } = useAccount();

const defaultSettings = {
  enable_chatbot_conversations_filter: false,
  chatbot_conversations_filter_roles: ['administrator'],
  enable_ai_conversations_filter: false,
  ai_conversations_filter_roles: ['administrator', 'agent'],
  enable_resolved_conversations_filter: false,
  enable_pending_conversations_filter: false,
  enable_pending_team_conversations_filter: true,
  enable_unassigned_conversations_filter: false,
  show_inbox_name_in_conversation_list: false,
  show_conversation_id_in_conversation_list: false,
  show_conversation_team_in_conversation_list: false,
  show_conversation_status_in_conversation_list: false,
  hide_conversations_assigned_to_others: false,
  hide_resolved_conversations_assigned_to_others: false,
  show_conversations_only_from_user_teams: false,
  enable_contact_company_filter: false,
  signature_agents_can_disable: false,
  agents_can_reopen_conversations: false,
  agents_can_join_conversations_as_participant: false,
  ignore_whatsapp_groups: false,
  enable_whatsapp_groups_filter: false,
  allow_create_whatsapp_groups: false,
  allow_end_whatsapp_groups: false,
  allow_transfer_whatsapp_groups: false,
  reactions_appear_as_response: false,
  conversation_filter_limits: {},
};

const settings = ref({ ...defaultSettings });

const syncSettings = () => {
  const accountSettings = currentAccount.value?.settings || {};
  Object.keys(defaultSettings).forEach(key => {
    if (key === 'conversation_filter_limits') {
      settings.value[key] = accountSettings[key] || {};
    } else if (key === 'chatbot_conversations_filter_roles') {
      settings.value[key] = accountSettings[key] || ['administrator'];
    } else if (key === 'ai_conversations_filter_roles') {
      settings.value[key] = accountSettings[key] || ['administrator', 'agent'];
    } else if (key === 'enable_pending_team_conversations_filter') {
      settings.value[key] = accountSettings[key] !== false;
    } else {
      settings.value[key] = accountSettings[key] === true;
    }
  });
};

watch(() => currentAccount.value?.id, syncSettings, { immediate: true });

const toggleChatbotRole = (role, checked) => {
  const roles = new Set(
    settings.value.chatbot_conversations_filter_roles || []
  );
  if (checked) roles.add(role);
  else roles.delete(role);
  settings.value.chatbot_conversations_filter_roles = [...roles];
};

const toggleAiRole = (role, checked) => {
  const roles = new Set(settings.value.ai_conversations_filter_roles || []);
  if (checked) roles.add(role);
  else roles.delete(role);
  settings.value.ai_conversations_filter_roles = [...roles];
};

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
          <div class="flex items-center justify-between gap-4">
            <span class="text-sm">{{
              t(
                'ATTENDANCE_SETTINGS.DISPLAY.ENABLE_CHATBOT_CONVERSATIONS_FILTER'
              )
            }}</span>
            <Switch v-model="settings.enable_chatbot_conversations_filter" />
          </div>
          <div
            v-if="settings.enable_chatbot_conversations_filter"
            class="flex flex-col gap-2 pl-4"
          >
            <label class="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                :checked="
                  settings.chatbot_conversations_filter_roles.includes(
                    'administrator'
                  )
                "
                @change="
                  toggleChatbotRole('administrator', $event.target.checked)
                "
              />
              {{ t('ATTENDANCE_SETTINGS.DISPLAY.ROLE_ADMINISTRATOR') }}
            </label>
            <label class="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                :checked="
                  settings.chatbot_conversations_filter_roles.includes('agent')
                "
                @change="toggleChatbotRole('agent', $event.target.checked)"
              />
              {{ t('ATTENDANCE_SETTINGS.DISPLAY.ROLE_AGENT') }}
            </label>
          </div>

          <div class="flex items-center justify-between gap-4">
            <span class="text-sm">{{
              t('ATTENDANCE_SETTINGS.DISPLAY.ENABLE_AI_CONVERSATIONS_FILTER')
            }}</span>
            <Switch v-model="settings.enable_ai_conversations_filter" />
          </div>
          <div
            v-if="settings.enable_ai_conversations_filter"
            class="flex flex-col gap-2 pl-4"
          >
            <label class="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                :checked="
                  settings.ai_conversations_filter_roles.includes(
                    'administrator'
                  )
                "
                @change="toggleAiRole('administrator', $event.target.checked)"
              />
              {{ t('ATTENDANCE_SETTINGS.DISPLAY.ROLE_ADMINISTRATOR') }}
            </label>
            <label class="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                :checked="
                  settings.ai_conversations_filter_roles.includes('agent')
                "
                @change="toggleAiRole('agent', $event.target.checked)"
              />
              {{ t('ATTENDANCE_SETTINGS.DISPLAY.ROLE_AGENT') }}
            </label>
          </div>

          <div
            v-for="key in [
              'enable_resolved_conversations_filter',
              'enable_pending_conversations_filter',
            ]"
            :key="key"
            class="flex items-center justify-between gap-4"
          >
            <span class="text-sm">{{
              t(`ATTENDANCE_SETTINGS.DISPLAY.${key.toUpperCase()}`)
            }}</span>
            <Switch v-model="settings[key]" />
          </div>

          <div
            v-if="settings.enable_pending_conversations_filter"
            class="flex items-center justify-between gap-4"
          >
            <span class="text-sm">{{
              t(
                'ATTENDANCE_SETTINGS.DISPLAY.ENABLE_PENDING_TEAM_CONVERSATIONS_FILTER'
              )
            }}</span>
            <Switch
              v-model="settings.enable_pending_team_conversations_filter"
            />
          </div>

          <div
            v-for="key in [
              'enable_unassigned_conversations_filter',
              'enable_contact_company_filter',
              'show_inbox_name_in_conversation_list',
              'show_conversation_id_in_conversation_list',
              'show_conversation_team_in_conversation_list',
              'show_conversation_status_in_conversation_list',
            ]"
            :key="key"
            class="flex items-center justify-between gap-4"
          >
            <span class="text-sm">{{
              t(`ATTENDANCE_SETTINGS.DISPLAY.${key.toUpperCase()}`)
            }}</span>
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
          <div
            v-for="key in [
              'hide_conversations_assigned_to_others',
              'show_conversations_only_from_user_teams',
            ]"
            :key="key"
            class="flex items-center justify-between gap-4"
          >
            <span class="text-sm">{{
              t(`ATTENDANCE_SETTINGS.VISIBILITY.${key.toUpperCase()}`)
            }}</span>
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
          <div
            v-for="key in [
              'signature_agents_can_disable',
              'agents_can_reopen_conversations',
              'agents_can_join_conversations_as_participant',
            ]"
            :key="key"
            class="flex items-center justify-between gap-4"
          >
            <span class="text-sm">{{
              t(`ATTENDANCE_SETTINGS.PERMISSIONS.${key.toUpperCase()}`)
            }}</span>
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
          <div
            v-for="key in [
              'ignore_whatsapp_groups',
              'enable_whatsapp_groups_filter',
              'allow_create_whatsapp_groups',
              'allow_end_whatsapp_groups',
              'allow_transfer_whatsapp_groups',
            ]"
            :key="key"
            class="flex items-center justify-between gap-4"
          >
            <span class="text-sm">{{
              t(`ATTENDANCE_SETTINGS.GROUPS.${key.toUpperCase()}`)
            }}</span>
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
            <span class="text-sm">{{
              t('ATTENDANCE_SETTINGS.OTHERS.REACTIONS_APPEAR_AS_RESPONSE')
            }}</span>
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
