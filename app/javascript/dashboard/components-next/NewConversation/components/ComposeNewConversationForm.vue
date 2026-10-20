<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { DirectUpload } from 'activestorage';
import { useVuelidate } from '@vuelidate/core';
import { required, requiredIf } from '@vuelidate/validators';
import { INBOX_TYPES, isVoiceCallEnabled } from 'dashboard/helper/inbox';
import {
  appendSignature,
  removeSignature,
  getEffectiveChannelType,
  stripUnsupportedMarkdown,
} from 'dashboard/helper/editorHelper';
import {
  buildContactableInboxesList,
  prepareNewMessagePayload,
  prepareWhatsAppMessagePayload,
} from 'dashboard/components-next/NewConversation/helpers/composeConversationHelper.js';

import { useAlert } from 'dashboard/composables';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useCopilotReply } from 'dashboard/composables/useCopilotReply';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import { setDirectUploadAuthHeaders } from 'dashboard/helper/directUploadsHelper';
import { AUDIO_FORMATS } from 'shared/constants/messages';

import ContactSelector from './ContactSelector.vue';
import TeamSelector from './TeamSelector.vue';
import InboxSelector from './InboxSelector.vue';
import EmailOptions from './EmailOptions.vue';
import MessageEditor from './MessageEditor.vue';
import ActionButtons from './ActionButtons.vue';
import InboxEmptyState from './InboxEmptyState.vue';
import AttachmentPreviews from './AttachmentPreviews.vue';
import CopilotReplyBottomPanel from 'dashboard/components/widgets/WootWriter/CopilotReplyBottomPanel.vue';
import AudioRecorder from 'dashboard/components/widgets/WootWriter/AudioRecorder.vue';

const props = defineProps({
  contacts: { type: Array, default: () => [] },
  contactId: { type: String, default: null },
  selectedContact: { type: Object, default: null },
  targetInbox: { type: Object, default: null },
  targetTeam: { type: Object, default: null },
  teams: { type: Array, default: () => [] },
  currentUser: { type: Object, default: null },
  isCreatingContact: { type: Boolean, default: false },
  isFetchingInboxes: { type: Boolean, default: false },
  isLoading: { type: Boolean, default: false },
  isDirectUploadsEnabled: { type: Boolean, default: false },
  contactConversationsUiFlags: { type: Object, default: null },
  contactsUiFlags: { type: Object, default: null },
  messageSignature: { type: String, default: '' },
  sendWithSignature: { type: Boolean, default: false },
  formState: { type: Object, required: true },
});

const emit = defineEmits([
  'searchContacts',
  'resetContactSearch',
  'discard',
  'updateSelectedContact',
  'updateTargetInbox',
  'updateTargetTeam',
  'clearSelectedContact',
  'createConversation',
]);

const DEFAULT_FORMATTING = 'Context::Default';

const { t } = useI18n();
const { agentsCanDisableSignature } = useUISettings();

const copilot = useCopilotReply();

const showContactsDropdown = ref(false);
const showInboxesDropdown = ref(false);
const showCcEmailsDropdown = ref(false);
const showBccEmailsDropdown = ref(false);

const isCreating = computed(() => props.contactConversationsUiFlags.isCreating);

const state = props.formState || {
  message: '',
  subject: '',
  ccEmails: '',
  bccEmails: '',
  attachedFiles: [],
};

const inboxTypes = computed(() => ({
  isEmail: props.targetInbox?.channelType === INBOX_TYPES.EMAIL,
  isTwilio: props.targetInbox?.channelType === INBOX_TYPES.TWILIO,
  isWhatsapp: props.targetInbox?.channelType === INBOX_TYPES.WHATSAPP,
  isWebWidget: props.targetInbox?.channelType === INBOX_TYPES.WEB,
  isApi: props.targetInbox?.channelType === INBOX_TYPES.API,
  isEmailOrWebWidget:
    props.targetInbox?.channelType === INBOX_TYPES.EMAIL ||
    props.targetInbox?.channelType === INBOX_TYPES.WEB,
  isTwilioSMS:
    props.targetInbox?.channelType === INBOX_TYPES.TWILIO &&
    props.targetInbox?.medium === 'sms',
  isTwilioWhatsapp:
    props.targetInbox?.channelType === INBOX_TYPES.TWILIO &&
    props.targetInbox?.medium === 'whatsapp',
  isUnofficialWhatsapp:
    props.targetInbox?.channelType === INBOX_TYPES.UNOFFICIAL_WHATSAPP,
}));

const whatsappMessageTemplates = computed(() =>
  Object.keys(props.targetInbox?.messageTemplates || {}).length
    ? props.targetInbox.messageTemplates
    : []
);

const inboxChannelType = computed(() => props.targetInbox?.channelType || '');

const inboxMedium = computed(() => props.targetInbox?.medium || '');

const isRecordingAudio = ref(false);
const recordingAudioState = ref('');
const recordingAudioDurationText = ref('00:00');
const audioRecorderRef = ref(null);

const audioRecordFormat = computed(() => AUDIO_FORMATS.OGG);

const hasAttachments = computed(
  () => state.attachedFiles.length > 0 || isRecordingAudio.value
);

const voiceCallEnabled = computed(() => isVoiceCallEnabled(props.targetInbox));

const effectiveChannelType = computed(() =>
  getEffectiveChannelType(inboxChannelType.value, inboxMedium.value)
);

const validationRules = computed(() => ({
  selectedContact: { required },
  targetInbox: { required },
  message: {
    required: requiredIf(
      !inboxTypes.value.isWhatsapp &&
        !inboxTypes.value.isTwilioWhatsapp &&
        !hasAttachments.value
    ),
  },
  subject: { required: requiredIf(inboxTypes.value.isEmail) },
}));

const v$ = useVuelidate(validationRules, {
  selectedContact: computed(() => props.selectedContact),
  targetInbox: computed(() => props.targetInbox),
  message: computed(() => state.message),
  subject: computed(() => state.subject),
});

const validationStates = computed(() => ({
  isContactInvalid:
    v$.value.selectedContact.$dirty && v$.value.selectedContact.$invalid,
  isInboxInvalid: v$.value.targetInbox.$dirty && v$.value.targetInbox.$invalid,
  isSubjectInvalid: v$.value.subject.$dirty && v$.value.subject.$invalid,
  isMessageInvalid: v$.value.message.$dirty && v$.value.message.$invalid,
}));

const newMessagePayload = () => {
  const { message, subject, ccEmails, bccEmails, attachedFiles } = state;
  return prepareNewMessagePayload({
    targetInbox: props.targetInbox,
    selectedContact: props.selectedContact,
    message,
    subject,
    ccEmails,
    bccEmails,
    currentUser: props.currentUser,
    attachedFiles,
    directUploadsEnabled: props.isDirectUploadsEnabled,
    teamId: props.targetTeam?.id,
  });
};

const contactableInboxesList = computed(() => {
  return buildContactableInboxesList(props.selectedContact?.contactInboxes);
});

const showNoInboxAlert = computed(() => {
  return (
    props.selectedContact &&
    contactableInboxesList.value.length === 0 &&
    !props.contactsUiFlags.isFetchingInboxes &&
    !props.isFetchingInboxes
  );
});

const isAnyDropdownActive = computed(() => {
  return (
    showContactsDropdown.value ||
    showInboxesDropdown.value ||
    showCcEmailsDropdown.value ||
    showBccEmailsDropdown.value
  );
});

const handleContactSearch = value => {
  showContactsDropdown.value = value.trim().length > 1;
  emit('searchContacts', value);
};

const handleDropdownUpdate = (type, value) => {
  if (type === 'cc') {
    showCcEmailsDropdown.value = value;
  } else if (type === 'bcc') {
    showBccEmailsDropdown.value = value;
  } else {
    showContactsDropdown.value = value;
  }
};

const searchCcEmails = value => {
  showBccEmailsDropdown.value = false;
  emit('resetContactSearch');
  showCcEmailsDropdown.value = value.trim().length >= 2;
  emit('searchContacts', value);
};

const searchBccEmails = value => {
  showCcEmailsDropdown.value = false;
  emit('resetContactSearch');
  showBccEmailsDropdown.value = value.trim().length >= 2;
  emit('searchContacts', value);
};

const setSelectedContact = async ({ value, action, ...rest }) => {
  v$.value.$reset();
  emit('updateSelectedContact', { value, action, ...rest });
  showContactsDropdown.value = false;
  showInboxesDropdown.value = true;
};

const stripMessageFormatting = channelType => {
  if (!state.message || !channelType) return;

  state.message = stripUnsupportedMarkdown(state.message, channelType, false);
};

const handleInboxAction = ({ value, action, channelType, medium, ...rest }) => {
  v$.value.$reset();
  copilot.reset(false);

  // Strip unsupported formatting when changing the target inbox
  if (channelType) {
    const newChannelType = getEffectiveChannelType(channelType, medium);
    stripMessageFormatting(newChannelType);
  }

  emit('updateTargetInbox', { ...rest, channelType, medium });
  showInboxesDropdown.value = false;
  state.attachedFiles = [];
};

const removeSignatureFromMessage = () => {
  // Always remove the signature from message content when inbox/contact is removed
  // to ensure no leftover signature content remains
  if (props.messageSignature) {
    state.message = removeSignature(
      state.message,
      props.messageSignature,
      effectiveChannelType.value
    );
  }
};

const removeTargetInbox = value => {
  v$.value.$reset();
  copilot.reset(false);
  removeSignatureFromMessage();

  stripMessageFormatting(DEFAULT_FORMATTING);

  emit('updateTargetInbox', value);
  state.attachedFiles = [];
};

const clearSelectedContact = () => {
  copilot.reset(false);
  removeSignatureFromMessage();
  emit('clearSelectedContact');
  state.message = '';
  state.attachedFiles = [];
};

const onClickInsertEmoji = emoji => {
  state.message += emoji;
};

const handleAddSignature = signature => {
  state.message = appendSignature(
    state.message,
    signature,
    effectiveChannelType.value
  );
};

const handleRemoveSignature = signature => {
  state.message = removeSignature(
    state.message,
    signature,
    effectiveChannelType.value
  );
};

const handleAttachFile = files => {
  state.attachedFiles = files;
};

const handleTargetTeam = team => {
  emit('updateTargetTeam', team);
};

const resetAudioRecorder = () => {
  recordingAudioDurationText.value = '00:00';
  isRecordingAudio.value = false;
  recordingAudioState.value = '';
  state.attachedFiles = state.attachedFiles.filter(
    file => !file.isVoiceMessage
  );
};

const toggleAudioRecorder = () => {
  if (isRecordingAudio.value) {
    audioRecorderRef.value?.stopRecording();
    resetAudioRecorder();
  } else {
    isRecordingAudio.value = true;
  }
};

const onRecordProgressChanged = duration => {
  recordingAudioDurationText.value = duration;
};

const attachRecordedAudio = file => {
  if (!props.isDirectUploadsEnabled) {
    state.attachedFiles = [
      ...state.attachedFiles,
      {
        resource: {
          id: `audio-${Date.now()}`,
          name: file.name,
          type: file.type,
          file,
        },
        isVoiceMessage: true,
      },
    ];
    return;
  }

  const upload = new DirectUpload(file, '/rails/active_storage/direct_uploads', {
    directUploadWillCreateBlobWithXHR: xhr => setDirectUploadAuthHeaders(xhr),
  });

  upload.create((error, blob) => {
    if (error) {
      useAlert(error);
      return;
    }
    state.attachedFiles = [
      ...state.attachedFiles,
      {
        resource: blob,
        blobSignedId: blob.signed_id,
        isVoiceMessage: true,
      },
    ];
  });
};

const onFinishRecorder = file => {
  recordingAudioState.value = 'stopped';
  attachRecordedAudio(file);
};

const onRecordError = payload => {
  resetAudioRecorder();
  const error = payload?.error || payload;
  const permissionErrors = [
    'NotAllowedError',
    'PermissionDeniedError',
    'SecurityError',
  ];
  const unavailableErrors = [
    'NotFoundError',
    'DevicesNotFoundError',
    'NotReadableError',
    'OverconstrainedError',
    'NotSupportedError',
  ];

  if (permissionErrors.includes(error?.name)) {
    useAlert(t('CONVERSATION.REPLYBOX.MICROPHONE_PERMISSION_DENIED'));
  } else if (unavailableErrors.includes(error?.name)) {
    useAlert(t('CONVERSATION.REPLYBOX.MICROPHONE_UNAVAILABLE'));
  } else {
    useAlert(t('CONVERSATION.REPLYBOX.AUDIO_CONVERSION_FAILED'));
  }
};

const clearForm = () => {
  copilot.reset(false);
  resetAudioRecorder();
  Object.assign(state, {
    message: '',
    subject: '',
    ccEmails: '',
    bccEmails: '',
    attachedFiles: [],
  });
  v$.value.$reset();
};

const ensureMandatorySignature = () => {
  if (
    agentsCanDisableSignature.value ||
    !props.messageSignature ||
    !state.message
  ) {
    return;
  }

  state.message = appendSignature(
    state.message,
    props.messageSignature,
    effectiveChannelType.value
  );
};

const handleSendMessage = async () => {
  const isValid = await v$.value.$validate();
  if (!isValid) return;

  ensureMandatorySignature();

  try {
    const success = await emit('createConversation', {
      payload: newMessagePayload(),
      isFromWhatsApp: false,
    });
    if (success) {
      clearForm();
    }
  } catch (error) {
    // Form will not be cleared if conversation creation fails
  }
};

const handleSendWhatsappMessage = async ({ message, templateParams }) => {
  const whatsappMessagePayload = prepareWhatsAppMessagePayload({
    targetInbox: props.targetInbox,
    selectedContact: props.selectedContact,
    message,
    templateParams,
    currentUser: props.currentUser,
    teamId: props.targetTeam?.id,
  });
  await emit('createConversation', {
    payload: whatsappMessagePayload,
    isFromWhatsApp: true,
  });
};

const handleSendTwilioMessage = async ({ message, templateParams }) => {
  const twilioMessagePayload = prepareWhatsAppMessagePayload({
    targetInbox: props.targetInbox,
    selectedContact: props.selectedContact,
    message,
    templateParams,
    currentUser: props.currentUser,
    teamId: props.targetTeam?.id,
  });
  await emit('createConversation', {
    payload: twilioMessagePayload,
    isFromWhatsApp: true,
  });
};

const shouldShowMessageEditor = computed(() => {
  return (
    !inboxTypes.value.isWhatsapp &&
    !showNoInboxAlert.value &&
    !inboxTypes.value.isTwilioWhatsapp
  );
});

const isCopilotActive = computed(() => copilot.isActive?.value ?? false);

const onSubmitCopilotReply = () => {
  const acceptedMessage = copilot.accept();
  state.message = acceptedMessage;
};

useKeyboardEvents({
  '$mod+Enter': {
    action: () => {
      if (isCopilotActive.value && !copilot.isButtonDisabled.value) {
        onSubmitCopilotReply();
      }
    },
    allowOnFocusedInput: true,
  },
});
</script>

<template>
  <div
    class="w-full md:w-[42rem] divide-y divide-n-strong overflow-visible transition-all duration-300 ease-in-out top-full flex flex-col bg-n-alpha-3 border border-n-strong shadow-sm backdrop-blur-[100px] rounded-xl min-w-0 max-h-[calc(100vh-8rem)]"
  >
    <div class="flex-1 overflow-y-auto divide-y divide-n-strong">
      <ContactSelector
        :contacts="contacts"
        :selected-contact="selectedContact"
        :show-contacts-dropdown="showContactsDropdown"
        :is-loading="isLoading"
        :is-creating-contact="isCreatingContact"
        :contact-id="contactId"
        :contactable-inboxes-list="contactableInboxesList"
        :show-inboxes-dropdown="showInboxesDropdown"
        :has-errors="validationStates.isContactInvalid"
        @search-contacts="handleContactSearch"
        @set-selected-contact="setSelectedContact"
        @clear-selected-contact="clearSelectedContact"
        @update-dropdown="handleDropdownUpdate"
      />
      <InboxEmptyState v-if="showNoInboxAlert" />
      <InboxSelector
        v-else
        :target-inbox="targetInbox"
        :selected-contact="selectedContact"
        :show-inboxes-dropdown="showInboxesDropdown"
        :contactable-inboxes-list="contactableInboxesList"
        :has-errors="validationStates.isInboxInvalid"
        :is-fetching-inboxes="isFetchingInboxes"
        @update-inbox="removeTargetInbox"
        @toggle-dropdown="showInboxesDropdown = $event"
        @handle-inbox-action="handleInboxAction"
      />

      <TeamSelector
        v-if="!showNoInboxAlert"
        :teams="teams"
        :target-team="targetTeam"
        @update-team="handleTargetTeam"
      />

      <EmailOptions
        v-if="inboxTypes.isEmail"
        v-model:cc-emails="state.ccEmails"
        v-model:bcc-emails="state.bccEmails"
        v-model:subject="state.subject"
        :contacts="contacts"
        :show-cc-emails-dropdown="showCcEmailsDropdown"
        :show-bcc-emails-dropdown="showBccEmailsDropdown"
        :is-loading="isLoading"
        :has-errors="validationStates.isSubjectInvalid"
        @search-cc-emails="searchCcEmails"
        @search-bcc-emails="searchBccEmails"
        @update-dropdown="handleDropdownUpdate"
      />

      <AudioRecorder
        v-if="isRecordingAudio"
        ref="audioRecorderRef"
        :audio-record-format="audioRecordFormat"
        @recorder-progress-changed="onRecordProgressChanged"
        @finish-record="onFinishRecorder"
        @record-error="onRecordError"
        @play="recordingAudioState = 'playing'"
        @pause="recordingAudioState = 'paused'"
      />
      <MessageEditor
        v-else-if="shouldShowMessageEditor"
        v-model="state.message"
        :message-signature="messageSignature"
        :send-with-signature="sendWithSignature"
        :has-errors="validationStates.isMessageInvalid"
        :channel-type="inboxChannelType"
        :medium="targetInbox?.medium || ''"
        :copilot="copilot"
      />

      <AttachmentPreviews
        v-if="state.attachedFiles.length > 0"
        :attachments="state.attachedFiles"
        @update:attachments="state.attachedFiles = $event"
      />
    </div>

    <CopilotReplyBottomPanel
      v-if="isCopilotActive"
      :is-generating-content="copilot.isButtonDisabled.value"
      class="h-[3.25rem] !px-4 !py-2"
      @submit="onSubmitCopilotReply"
      @cancel="copilot.reset"
    />
    <ActionButtons
      v-else
      :attached-files="state.attachedFiles"
      :is-whatsapp-inbox="inboxTypes.isWhatsapp"
      :is-unofficial-whatsapp-inbox="inboxTypes.isUnofficialWhatsapp"
      :is-recording-audio="isRecordingAudio"
      :recording-audio-duration-text="recordingAudioDurationText"
      :recording-audio-state="recordingAudioState"
      :is-email-or-web-widget-inbox="inboxTypes.isEmailOrWebWidget"
      :is-twilio-sms-inbox="inboxTypes.isTwilioSMS"
      :is-twilio-whats-app-inbox="inboxTypes.isTwilioWhatsapp"
      :message-templates="whatsappMessageTemplates"
      :channel-type="inboxChannelType"
      :voice-enabled="voiceCallEnabled"
      :is-loading="isCreating"
      :disable-send-button="isCreating"
      :has-selected-inbox="!!targetInbox"
      :inbox-id="targetInbox?.id"
      :has-no-inbox="showNoInboxAlert"
      :is-dropdown-active="isAnyDropdownActive"
      :message-signature="messageSignature"
      @insert-emoji="onClickInsertEmoji"
      @add-signature="handleAddSignature"
      @remove-signature="handleRemoveSignature"
      @attach-file="handleAttachFile"
      @toggle-audio-recorder="toggleAudioRecorder"
      @discard="$emit('discard')"
      @send-message="handleSendMessage"
      @send-whatsapp-message="handleSendWhatsappMessage"
      @send-twilio-message="handleSendTwilioMessage"
    />
  </div>
</template>
