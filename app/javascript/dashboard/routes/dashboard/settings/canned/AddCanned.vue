<script>
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';

import NextButton from 'dashboard/components-next/button/Button.vue';
import NextSwitch from 'dashboard/components-next/switch/Switch.vue';
import Modal from '../../../../components/Modal.vue';
import CannedMessageEditor from './CannedMessageEditor.vue';

export default {
  name: 'AddCanned',
  components: {
    NextButton,
    NextSwitch,
    Modal,
    CannedMessageEditor,
  },
  props: {
    responseContent: {
      type: String,
      default: '',
    },
    messageType: {
      type: String,
      default: 'quick',
    },
    onClose: {
      type: Function,
      default: () => {},
    },
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      shortCode: '',
      content: this.responseContent || '',
      availableForAllInboxes: true,
      inboxIds: [],
      addCanned: {
        showLoading: false,
        message: '',
      },
      show: true,
    };
  },
  computed: {
    inboxes() {
      return this.$store.getters['inboxes/getInboxes'];
    },
    isAvailabilityValid() {
      return this.availableForAllInboxes || this.inboxIds.length > 0;
    },
    isFarewell() {
      return this.messageType === 'farewell';
    },
    modalTitle() {
      return this.isFarewell
        ? this.$t('CANNED_MGMT.ADD.FAREWELL_TITLE')
        : this.$t('CANNED_MGMT.ADD.TITLE');
    },
    modalDescription() {
      return this.isFarewell
        ? this.$t('CANNED_MGMT.ADD.FAREWELL_DESC')
        : this.$t('CANNED_MGMT.ADD.DESC');
    },
  },
  validations: {
    shortCode: {
      required,
      minLength: minLength(2),
    },
    content: {
      required,
    },
  },
  mounted() {
    this.$store.dispatch('inboxes/get');
  },
  methods: {
    resetForm() {
      this.shortCode = '';
      this.content = '';
      this.v$.shortCode.$reset();
      this.v$.content.$reset();
    },
    addCannedResponse() {
      // Show loading on button
      this.addCanned.showLoading = true;
      // Make API Calls
      this.$store
        .dispatch('createCannedResponse', {
          short_code: this.shortCode,
          content: this.content,
          message_type: this.messageType,
          available_for_all_inboxes: this.availableForAllInboxes,
          inbox_ids: this.inboxIds,
        })
        .then(() => {
          // Reset Form, Show success message
          this.addCanned.showLoading = false;
          useAlert(this.$t('CANNED_MGMT.ADD.API.SUCCESS_MESSAGE'));
          this.resetForm();
          this.onClose();
        })
        .catch(error => {
          this.addCanned.showLoading = false;
          const errorMessage =
            error?.message || this.$t('CANNED_MGMT.ADD.API.ERROR_MESSAGE');
          useAlert(errorMessage);
        });
    },
  },
};
</script>

<template>
  <Modal v-model:show="show" :on-close="onClose">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="modalTitle"
        :header-content="modalDescription"
      />
      <form class="flex flex-col w-full" @submit.prevent="addCannedResponse()">
        <div class="w-full">
          <label :class="{ error: v$.shortCode.$error }">
            {{ $t('CANNED_MGMT.ADD.FORM.SHORT_CODE.LABEL') }}
            <input
              v-model="shortCode"
              type="text"
              :placeholder="$t('CANNED_MGMT.ADD.FORM.SHORT_CODE.PLACEHOLDER')"
              @blur="v$.shortCode.$touch"
            />
          </label>
        </div>

        <div class="w-full">
          <label :class="{ error: v$.content.$error }">
            {{ $t('CANNED_MGMT.ADD.FORM.CONTENT.LABEL') }}
          </label>
          <div class="editor-wrap">
            <CannedMessageEditor
              v-model="content"
              :has-error="v$.content.$error"
              :placeholder="$t('CANNED_MGMT.ADD.FORM.CONTENT.PLACEHOLDER')"
              @blur="v$.content.$touch"
            />
          </div>
        </div>

        <div class="flex flex-col w-full gap-3">
          <div class="flex items-center justify-between gap-4">
            <span class="text-sm">
              {{ $t('CANNED_MGMT.AVAILABILITY.ALL_INBOXES') }}
            </span>
            <NextSwitch v-model="availableForAllInboxes" />
          </div>
          <div v-if="!availableForAllInboxes" class="flex flex-col gap-2">
            <span class="text-sm text-n-slate-11">
              {{ $t('CANNED_MGMT.AVAILABILITY.SELECT_INBOXES') }}
            </span>
            <div
              class="flex flex-col gap-2 p-3 overflow-y-auto border rounded-lg max-h-48 border-n-weak"
            >
              <label
                v-for="inbox in inboxes"
                :key="inbox.id"
                class="flex items-center gap-2 text-sm"
              >
                <input v-model="inboxIds" type="checkbox" :value="inbox.id" />
                {{ inbox.name }}
              </label>
            </div>
          </div>
        </div>

        <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
          <NextButton
            faded
            slate
            type="reset"
            :label="$t('CANNED_MGMT.ADD.CANCEL_BUTTON_TEXT')"
            @click.prevent="onClose"
          />
          <NextButton
            type="submit"
            :label="$t('CANNED_MGMT.ADD.FORM.SUBMIT')"
            :disabled="
              v$.content.$invalid ||
              v$.shortCode.$invalid ||
              !isAvailabilityValid ||
              addCanned.showLoading
            "
            :is-loading="addCanned.showLoading"
          />
        </div>
      </form>
    </div>
  </Modal>
</template>
