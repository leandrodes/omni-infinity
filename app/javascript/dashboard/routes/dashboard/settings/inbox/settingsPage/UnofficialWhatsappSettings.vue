<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
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
  setup() {
    const { currentAccount } = useAccount();
    return { currentAccount };
  },
  data() {
    return {
      connectionStatus: this.inbox.connection_status || 'initial',
      qrCode: '',
      pollTimer: null,
      isWorking: false,
      activeProvider: this.inbox.provider || '',
      selectedProvider: this.inbox.provider || '',
      isSavingProvider: false,
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
    enabledFeatures() {
      return this.currentAccount?.features || {};
    },
    providerEnabled() {
      return {
        wuzapi: Boolean(this.enabledFeatures.saas_channel_wuzapi),
        evolution: Boolean(this.enabledFeatures.saas_channel_evolution),
        uzapi: false,
      };
    },
    providerChanged() {
      return (
        this.selectedProvider &&
        this.selectedProvider !== this.activeProvider
      );
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
    applyStatus({ connection_status: status, logged_in: loggedIn, provider }) {
      if (provider) {
        if (
          !this.selectedProvider ||
          this.selectedProvider === this.activeProvider
        ) {
          this.selectedProvider = provider;
        }
        this.activeProvider = provider;
      }
      if (status) {
        this.connectionStatus = status;
      }
      if (status === 'connected' || loggedIn) {
        this.connectionStatus = 'connected';
        this.stopPolling();
      }
    },
    async saveProvider() {
      if (
        !this.selectedProvider ||
        !this.providerEnabled[this.selectedProvider]
      ) {
        useAlert(
          this.$t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.PROVIDER.DISABLED')
        );
        return;
      }
      if (!this.providerChanged) return;

      this.isSavingProvider = true;
      try {
        await UnofficialWhatsappAPI.updateProvider(
          this.inbox.id,
          this.selectedProvider
        );
        this.activeProvider = this.selectedProvider;
        useAlert(
          this.$t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.PROVIDER.CHANGED')
        );
        this.connectionStatus = 'initial';
        this.qrCode = '';
        this.stopPolling();
        await this.reconnect();
      } catch (error) {
        useAlert(
          error?.response?.data?.message ||
            error?.message ||
            this.$t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.FAILED')
        );
      } finally {
        this.isSavingProvider = false;
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
  <div class="flex flex-col gap-8">
    <SettingsFieldSection
      :label="$t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.PROVIDER.SETTINGS_TITLE')"
      :help-text="$t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.PROVIDER.SETTINGS_HELP')"
    >
      <div class="flex flex-col gap-4">
        <select v-model="selectedProvider" class="w-full max-w-md">
          <option value="" disabled>
            {{
              $t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.PROVIDER.PLACEHOLDER')
            }}
          </option>
          <option
            value="wuzapi"
            :disabled="!providerEnabled.wuzapi"
            :class="{ 'text-red-600': !providerEnabled.wuzapi }"
          >
            {{ $t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.PROVIDER.WUZAPI') }}
          </option>
          <option
            value="evolution"
            :disabled="!providerEnabled.evolution"
            :class="{ 'text-red-600': !providerEnabled.evolution }"
          >
            {{ $t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.PROVIDER.EVOLUTION') }}
          </option>
          <option
            value="uzapi"
            :disabled="!providerEnabled.uzapi"
            :class="{ 'text-red-600': !providerEnabled.uzapi }"
          >
            {{ $t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.PROVIDER.UZAPI') }}
          </option>
        </select>

        <span
          v-if="!providerEnabled.wuzapi"
          class="text-xs text-red-600"
        >
          WuzAPI —
          {{ $t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.PROVIDER.DISABLED') }}
        </span>
        <span
          v-if="!providerEnabled.evolution"
          class="text-xs text-red-600"
        >
          Evolution API —
          {{ $t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.PROVIDER.DISABLED') }}
        </span>
        <span
          v-if="!providerEnabled.uzapi"
          class="text-xs text-red-600"
        >
          UazAPI —
          {{ $t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.PROVIDER.UNAVAILABLE') }}
        </span>

        <div>
          <NextButton
            :disabled="!providerChanged || isSavingProvider"
            :is-loading="isSavingProvider"
            solid
            blue
            :label="$t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.PROVIDER.SAVE')"
            @click="saveProvider"
          />
        </div>
      </div>
    </SettingsFieldSection>

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
  </div>
</template>
