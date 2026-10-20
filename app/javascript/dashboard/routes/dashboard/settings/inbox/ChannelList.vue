<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';

import { useAccount } from 'dashboard/composables/useAccount';

import ChannelItem from 'dashboard/components/widgets/ChannelItem.vue';

const { t } = useI18n();
const router = useRouter();
const { accountId, currentAccount } = useAccount();

const globalConfig = useMapGetter('globalConfig/get');

const enabledFeatures = computed(() => currentAccount.value?.features || {});

const hasUnofficialWhatsappProvider = computed(() => {
  const features = enabledFeatures.value;
  return Boolean(
    features.saas_channel_wuzapi ||
      features.saas_channel_evolution ||
      features.saas_channel_uzapi
  );
});

const channelList = computed(() => {
  const { apiChannelName } = globalConfig.value;
  const features = enabledFeatures.value;
  const channels = [
    {
      key: 'website',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.WEBSITE.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.WEBSITE.DESCRIPTION'),
      icon: 'i-woot-website',
    },
  ];

  if (features.channel_facebook) {
    channels.push({
      key: 'facebook',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.FACEBOOK.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.FACEBOOK.DESCRIPTION'),
      icon: 'i-woot-messenger',
    });
  }

  channels.push({
    key: 'whatsapp',
    title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.WHATSAPP.TITLE'),
    description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.WHATSAPP.DESCRIPTION'),
    icon: 'i-woot-whatsapp',
  });

  if (hasUnofficialWhatsappProvider.value) {
    channels.push({
      key: 'unofficial_whatsapp',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.UNOFFICIAL_WHATSAPP.TITLE'),
      description: t(
        'INBOX_MGMT.ADD.AUTH.CHANNEL.UNOFFICIAL_WHATSAPP.DESCRIPTION'
      ),
      icon: 'i-woot-whatsapp',
    });
  }

  channels.push(
    {
      key: 'sms',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.SMS.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.SMS.DESCRIPTION'),
      icon: 'i-woot-sms',
    },
    {
      key: 'email',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.EMAIL.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.EMAIL.DESCRIPTION'),
      icon: 'i-woot-mail',
    },
    {
      key: 'api',
      title: apiChannelName || t('INBOX_MGMT.ADD.AUTH.CHANNEL.API.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.API.DESCRIPTION'),
      icon: 'i-woot-api',
    },
    {
      key: 'telegram',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.TELEGRAM.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.TELEGRAM.DESCRIPTION'),
      icon: 'i-woot-telegram',
    }
  );

  if (features.channel_instagram) {
    channels.push({
      key: 'instagram',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.INSTAGRAM.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.INSTAGRAM.DESCRIPTION'),
      icon: 'i-woot-instagram',
    });
  }

  if (features.channel_tiktok) {
    channels.push({
      key: 'tiktok',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.TIKTOK.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.TIKTOK.DESCRIPTION'),
      icon: 'i-woot-tiktok',
    });
  }

  if (features.channel_voice) {
    channels.push({
      key: 'voice',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.VOICE.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.VOICE.DESCRIPTION'),
      icon: 'i-woot-voice',
    });
  }

  if (features.saas_channel_wacalls) {
    channels.push({
      key: 'whatsapp_call',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.WHATSAPP_CALL.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.WHATSAPP_CALL.DESCRIPTION'),
      icon: 'i-woot-whatsapp',
    });
  }

  return channels;
});

const initChannelAuth = channel => {
  const params = {
    sub_page: channel,
    accountId: accountId.value,
  };
  router.push({ name: 'settings_inboxes_page_channel', params });
};
</script>

<template>
  <div
    class="grid max-w-3xl grid-cols-1 xs:grid-cols-2 mx-0 gap-6 sm:grid-cols-3 p-8"
  >
    <ChannelItem
      v-for="channel in channelList"
      :key="channel.key"
      :channel="channel"
      :enabled-features="enabledFeatures"
      @channel-item-click="initChannelAuth"
    />
  </div>
</template>
