<script>
/* eslint no-console: 0 */
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import NextSwitch from 'dashboard/components-next/switch/Switch.vue';
import Modal from '../../../../components/Modal.vue';
import CannedMessageEditor from './CannedMessageEditor.vue';

export default {
  components: {
    NextButton,
    NextSwitch,
    Modal,
    CannedMessageEditor,
  },
  props: {
    id: { type: Number, default: null },
    edcontent: { type: String, default: '' },
    edshortCode: { type: String, default: '' },
    messageType: { type: String, default: 'quick' },
    initialAvailableForAllInboxes: { type: Boolean, default: true },
    initialInboxIds: { type: Array, default: () => [] },
    onClose: { type: Function, default: () => {} },
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      editCanned: {
        showAlert: false,
        showLoading: false,
      },
      shortCode: this.edshortCode,
      content: this.edcontent,
      availableForAllInboxes: this.initialAvailableForAllInboxes,
      inboxIds: [...this.initialInboxIds],
      show: true,
    };
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
  computed: {
    inboxes() {
      return this.$store.getters['inboxes/getInboxes'];
    },
    isAvailabilityValid() {
      return this.availableForAllInboxes || this.inboxIds.length > 0;
    },
    pageTitle() {
      const title =
        this.messageType === 'farewell'
          ? this.$t('CANNED_MGMT.EDIT.FAREWELL_TITLE')
          : this.$t('CANNED_MGMT.EDIT.TITLE');
      return `${title} - ${this.edshortCode}`;
    },
  },
  mounted() {
    this.$store.dispatch('inboxes/get');
  },
  methods: {
    setPageName({ name }) {
      this.v$.content.$touch();
      this.content = name;
    },
    resetForm() {
      this.shortCode = '';
      this.content = '';
      this.v$.shortCode.$reset();
      this.v$.content.$reset();
    },
    editCannedResponse() {
      // Show loading on button
      this.editCanned.showLoading = true;
      // Make API Calls
      this.$store
        .dispatch('updateCannedResponse', {
          id: this.id,
          short_code: this.shortCode,
          content: this.content,
          message_type: this.messageType,
          available_for_all_inboxes: this.availableForAllInboxes,
          inbox_ids: this.inboxIds,
        })
        .then(() => {
          // Reset Form, Show success message
          this.editCanned.showLoading = false;
          useAlert(this.$t('CANNED_MGMT.EDIT.API.SUCCESS_MESSAGE'));
          this.resetForm();
          setTimeout(() => {
            this.onClose();
          }, 10);
        })
        .catch(error => {
          this.editCanned.showLoading = false;
          const errorMessage =
            error?.message || this.$t('CANNED_MGMT.EDIT.API.ERROR_MESSAGE');
          useAlert(errorMessage);
        });
    },
  },
};
</script>

<template>
  <Modal v-model:show="show" :on-close="onClose">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header :header-title="pageTitle" />
      <form class="flex flex-col w-full" @submit.prevent="editCannedResponse()">
        <div class="w-full">
          <label :class="{ error: v$.shortCode.$error }">
            {{ $t('CANNED_MGMT.EDIT.FORM.SHORT_CODE.LABEL') }}
            <input
              v-model="shortCode"
              type="text"
              :placeholder="$t('CANNED_MGMT.EDIT.FORM.SHORT_CODE.PLACEHOLDER')"
              @input="v$.shortCode.$touch"
            />
          </label>
        </div>

        <div class="w-full">
          <label :class="{ error: v$.content.$error }">
            {{ $t('CANNED_MGMT.EDIT.FORM.CONTENT.LABEL') }}
          </label>
          <div class="editor-wrap">
            <CannedMessageEditor
              v-model="content"
              :has-error="v$.content.$error"
              :placeholder="$t('CANNED_MGMT.EDIT.FORM.CONTENT.PLACEHOLDER')"
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
            :label="$t('CANNED_MGMT.EDIT.CANCEL_BUTTON_TEXT')"
            @click.prevent="onClose"
          />
          <NextButton
            type="submit"
            :label="$t('CANNED_MGMT.EDIT.FORM.SUBMIT')"
            :disabled="
              v$.content.$invalid ||
              v$.shortCode.$invalid ||
              !isAvailabilityValid ||
              editCanned.showLoading
            "
            :is-loading="editCanned.showLoading"
          />
        </div>
      </form>
    </div>
  </Modal>
</template>
