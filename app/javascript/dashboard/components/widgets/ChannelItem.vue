<script setup>
import { computed } from 'vue';
import { useAccount } from 'dashboard/composables/useAccount';
import ChannelSelector from '../ChannelSelector.vue';

const props = defineProps({
  channel: {
    type: Object,
    required: true,
  },
  enabledFeatures: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['channelItemClick']);
const { isOnChatwootCloud } = useAccount();

const hasTiktokConfigured = computed(() => {
  return window.chatwootConfig?.tiktokAppId;
});

const hasUnofficialWhatsappProvider = computed(() => {
  return Boolean(
    props.enabledFeatures.saas_channel_wuzapi ||
      props.enabledFeatures.saas_channel_evolution ||
      props.enabledFeatures.saas_channel_uzapi
  );
});

const isActive = computed(() => {
  const { key } = props.channel;
  if (Object.keys(props.enabledFeatures).length === 0) {
    return false;
  }
  if (key === 'website') {
    return props.enabledFeatures.channel_website;
  }
  if (key === 'facebook') {
    return props.enabledFeatures.channel_facebook;
  }
  if (key === 'email') {
    return props.enabledFeatures.channel_email;
  }

  if (key === 'instagram') {
    return props.enabledFeatures.channel_instagram;
  }

  if (key === 'tiktok') {
    return props.enabledFeatures.channel_tiktok;
  }

  if (key === 'voice') {
    return props.enabledFeatures.channel_voice;
  }

  if (key === 'whatsapp_call') {
    return props.enabledFeatures.saas_channel_wacalls;
  }

  if (key === 'unofficial_whatsapp') {
    return hasUnofficialWhatsappProvider.value;
  }

  return [
    'website',
    'twilio',
    'api',
    'whatsapp',
    'unofficial_whatsapp',
    'sms',
    'telegram',
    'line',
    'instagram',
    'tiktok',
    'voice',
  ].includes(key);
});

const isComingSoon = computed(() => false);

const isBeta = computed(() => {
  return ['tiktok', 'voice', 'whatsapp_call'].includes(props.channel.key);
});

const canRequestTiktokAccess = computed(() => {
  return (
    props.channel.key === 'tiktok' &&
    isOnChatwootCloud.value &&
    hasTiktokConfigured.value &&
    Object.keys(props.enabledFeatures).length > 0 &&
    !props.enabledFeatures.channel_tiktok
  );
});

const hasVoiceBadge = computed(() => {
  if (props.channel.key === 'voice') {
    return !!props.enabledFeatures.channel_voice;
  }
  if (props.channel.key === 'whatsapp_call') {
    return !!props.enabledFeatures.saas_channel_wacalls;
  }
  return false;
});

const onItemClick = () => {
  if (canRequestTiktokAccess.value) {
    window.$chatwoot?.toggle();
    return;
  }

  if (isActive.value) {
    emit('channelItemClick', props.channel.key);
  }
};
</script>

<template>
  <ChannelSelector
    :title="channel.title"
    :description="channel.description"
    :icon="channel.icon"
    :is-coming-soon="isComingSoon"
    :is-beta="isBeta"
    :has-voice-badge="hasVoiceBadge"
    :disabled="!isActive && !canRequestTiktokAccess"
    @click="onItemClick"
  />
</template>
