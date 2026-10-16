<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import UnofficialWhatsappAPI from 'dashboard/api/unofficialWhatsapp';
import SettingsFieldSection from 'dashboard/components-next/Settings/SettingsFieldSection.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const POLL_INTERVAL = 3000;

export default {
  components: {
    SettingsFieldSection,
    NextButton,
  },
  props: {
    inbox: {
      type: Object,
      default: () => ({}),
    },
  },
  data() {
    return {
      connectionStatus: this.inbox.connection_status || 'initial',
      qrCode: '',
      pollTimer: null,
      isWorking: false,
    };
  },
  computed: {
    ...mapGetters({ uiFlags: 'inboxes/getUIFlags' }),
    statusLabel() {
      const key = this.connectionStatus?.toUpperCase() || 'INITIAL';
      return this.$t(`INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.STATUS_${key}`);
    },
    isConnected() {
      return this.connectionStatus === 'connected';
    },
    isWaitingForScan() {
      return !this.isConnected;
    },
  },
  mounted() {
    this.fetchStatus().then(() => {
      if (!this.isConnected) {
        this.startPolling();
      }
    });
  },
  beforeUnmount() {
    this.stopPolling();
  },
  methods: {
    async fetchStatus() {
      try {
        const { data } = await UnofficialWhatsappAPI.status(this.inbox.id);
        this.applyStatus(data);
      } catch (_) {
        // keep the last known status
      }
    },
    applyStatus({ connection_status: status, logged_in: loggedIn }) {
      if (status) {
        this.connectionStatus = status;
      }
      if (status === 'connected' || loggedIn) {
        this.connectionStatus = 'connected';
        this.stopPolling();
      }
    },
    async reconnect() {
      this.isWorking = true;
      try {
        await UnofficialWhatsappAPI.connect(this.inbox.id);
        this.connectionStatus = 'connecting';
        this.startPolling();
      } catch (error) {
        useAlert(
          error?.message ||
            this.$t('INBOX_MGMT.SETTINGS_POPUP.WHATSAPP_RECONFIGURE_ERROR')
        );
      } finally {
        this.isWorking = false;
      }
    },
    async disconnect() {
      this.isWorking = true;
      try {
        await UnofficialWhatsappAPI.logout(this.inbox.id);
        this.connectionStatus = 'disconnected';
        this.qrCode = '';
        this.stopPolling();
      } catch (error) {
        useAlert(
          error?.message ||
            this.$t('INBOX_MGMT.SETTINGS_POPUP.WHATSAPP_RECONFIGURE_ERROR')
        );
      } finally {
        this.isWorking = false;
      }
    },
    startPolling() {
      this.fetchQrcode();
      this.pollTimer = setInterval(() => {
        if (this.isWaitingForScan) {
          this.fetchQrcode();
          this.fetchStatus();
        }
      }, POLL_INTERVAL);
    },
    stopPolling() {
      if (this.pollTimer) {
        clearInterval(this.pollTimer);
        this.pollTimer = null;
      }
    },
    async fetchQrcode() {
      try {
        const { data } = await UnofficialWhatsappAPI.qrcode(this.inbox.id);
        if (data?.qr_code) {
          this.qrCode = data.qr_code;
        }
      } catch (_) {
        // transient errors are expected while the session boots; keep polling
      }
    },
  },
};
</script>

<template>
  <SettingsFieldSection
    :label="$t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.TITLE')"
    :help-text="$t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.DESCRIPTION')"
  >
    <div class="flex flex-col gap-4">
      <div class="flex items-center gap-2">
        <span
          class="inline-block rounded-full size-2"
          :class="isConnected ? 'bg-n-teal-9' : 'bg-n-amber-9'"
        />
        <span class="text-body-main text-n-slate-12">{{ statusLabel }}</span>
      </div>

      <div
        v-if="isWaitingForScan && qrCode"
        class="flex items-center justify-center p-3 bg-white border rounded-2xl size-56 border-n-weak"
      >
        <img
          :src="qrCode"
          alt="WhatsApp QR"
          class="object-contain size-full"
        />
      </div>

      <div class="flex gap-3">
        <NextButton
          v-if="!isConnected"
          :disabled="isWorking"
          :is-loading="isWorking"
          solid
          blue
          :label="$t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.SUBMIT_BUTTON')"
          @click="reconnect"
        />
        <NextButton
          v-else
          :disabled="isWorking"
          :is-loading="isWorking"
          ruby
          :label="$t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.LOGOUT')"
          @click="disconnect"
        />
      </div>
    </div>
  </SettingsFieldSection>
</template>
