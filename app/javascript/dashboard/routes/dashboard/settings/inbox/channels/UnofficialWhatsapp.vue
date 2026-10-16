<script>
import { mapGetters } from 'vuex';
import { useVuelidate } from '@vuelidate/core';
import { useAlert } from 'dashboard/composables';
import { required } from '@vuelidate/validators';
import router from '../../../../index';
import { isPhoneE164OrEmpty } from 'shared/helpers/Validators';
import UnofficialWhatsappAPI from 'dashboard/api/unofficialWhatsapp';

import NextButton from 'dashboard/components-next/button/Button.vue';

const POLL_INTERVAL = 3000;

export default {
  components: {
    NextButton,
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      inboxName: '',
      phoneNumber: '',
      step: 'form',
      qrCode: '',
      connectionStatus: 'initial',
      inboxId: null,
      pollTimer: null,
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
  },
  validations: {
    inboxName: { required },
    phoneNumber: { isPhoneE164OrEmpty },
  },
  beforeUnmount() {
    this.stopPolling();
  },
  methods: {
    async createChannel() {
      this.v$.$touch();
      if (this.v$.$invalid) {
        return;
      }

      try {
        const inbox = await this.$store.dispatch('inboxes/createChannel', {
          name: this.inboxName?.trim(),
          channel: {
            type: 'unofficial_whatsapp',
            provider: 'wuzapi',
            phone_number: this.phoneNumber,
          },
        });
        this.inboxId = inbox.id;
        this.step = 'qr';
        await this.connect();
      } catch (error) {
        useAlert(
          error?.message || this.$t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.FAILED')
        );
      }
    },
    async connect() {
      try {
        await UnofficialWhatsappAPI.connect(this.inboxId);
        this.connectionStatus = 'connecting';
        this.startPolling();
      } catch (error) {
        this.connectionStatus = 'failed';
        useAlert(
          error?.message || this.$t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.FAILED')
        );
      }
    },
    startPolling() {
      this.fetchQrcode();
      this.fetchStatus();
      this.pollTimer = setInterval(() => {
        if (!this.isConnected) {
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
        const { data } = await UnofficialWhatsappAPI.qrcode(this.inboxId);
        if (data?.qr_code) {
          this.qrCode = data.qr_code;
        }
      } catch (_) {
        // transient errors are expected while the session boots; keep polling
      }
    },
    async fetchStatus() {
      try {
        const { data } = await UnofficialWhatsappAPI.status(this.inboxId);
        if (data?.connection_status) {
          this.connectionStatus = data.connection_status;
        }
        if (data?.connection_status === 'connected' || data?.logged_in) {
          this.connectionStatus = 'connected';
          this.stopPolling();
        }
      } catch (_) {
        // transient errors are expected while the session boots; keep polling
      }
    },
    goToAgents() {
      this.stopPolling();
      router.replace({
        name: 'settings_inboxes_add_agents',
        params: { page: 'new', inbox_id: this.inboxId },
      });
    },
  },
};
</script>

<template>
  <div class="max-w-2xl mx-0">
    <div v-if="step === 'form'">
      <div class="mb-8">
        <h1 class="mb-2 text-lg font-medium text-n-slate-12">
          {{ $t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.TITLE') }}
        </h1>
        <p class="text-sm leading-relaxed text-n-slate-11">
          {{ $t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.DESCRIPTION') }}
        </p>
      </div>

      <form class="flex flex-col flex-wrap mx-0" @submit.prevent="createChannel">
        <div class="flex-shrink-0 flex-grow-0">
          <label :class="{ error: v$.inboxName.$error }">
            {{ $t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.INBOX_NAME.LABEL') }}
            <input
              v-model="inboxName"
              type="text"
              :placeholder="
                $t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.INBOX_NAME.PLACEHOLDER')
              "
              @blur="v$.inboxName.$touch"
            />
            <span v-if="v$.inboxName.$error" class="message">
              {{ $t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.INBOX_NAME.ERROR') }}
            </span>
          </label>
        </div>

        <div class="flex-shrink-0 flex-grow-0">
          <label :class="{ error: v$.phoneNumber.$error }">
            {{ $t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.PHONE_NUMBER.LABEL') }}
            <input
              v-model="phoneNumber"
              type="text"
              :placeholder="
                $t(
                  'INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.PHONE_NUMBER.PLACEHOLDER'
                )
              "
              @blur="v$.phoneNumber.$touch"
            />
            <span v-if="v$.phoneNumber.$error" class="message">
              {{ $t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.PHONE_NUMBER.ERROR') }}
            </span>
          </label>
        </div>

        <div class="w-full mt-4">
          <NextButton
            :disabled="uiFlags.isCreating"
            :is-loading="uiFlags.isCreating"
            type="submit"
            solid
            blue
            :label="$t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.SUBMIT_BUTTON')"
          />
        </div>
      </form>
    </div>

    <div v-else class="flex flex-col items-center text-center">
      <h1 class="mb-2 text-lg font-medium text-n-slate-12">
        {{
          isConnected
            ? $t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.CONNECTED')
            : $t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.SCAN_TITLE')
        }}
      </h1>
      <p class="mb-6 max-w-md text-sm leading-relaxed text-n-slate-11">
        {{
          isConnected
            ? statusLabel
            : $t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.SCAN_DESCRIPTION')
        }}
      </p>

      <div
        v-if="!isConnected"
        class="flex items-center justify-center p-4 mb-6 bg-white border rounded-2xl size-64 border-n-weak"
      >
        <img
          v-if="qrCode"
          :src="qrCode"
          alt="WhatsApp QR"
          class="object-contain size-full"
        />
        <span v-else class="text-sm text-n-slate-11">
          {{ $t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.WAITING') }}
        </span>
      </div>

      <p v-if="!isConnected" class="mb-6 text-sm text-n-slate-11">
        {{ statusLabel }}
      </p>

      <NextButton
        v-if="isConnected"
        solid
        blue
        :label="$t('INBOX_MGMT.ADD.UNOFFICIAL_WHATSAPP.CONTINUE')"
        @click="goToAgents"
      />
    </div>
  </div>
</template>
