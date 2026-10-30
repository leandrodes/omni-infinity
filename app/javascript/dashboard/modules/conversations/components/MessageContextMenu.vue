<script>
import { useAlert } from 'dashboard/composables';
import { mapGetters } from 'vuex';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import ContextMenu from 'dashboard/components/ui/ContextMenu.vue';
import AddCannedModal from 'dashboard/routes/dashboard/settings/canned/AddCanned.vue';
import { useSnakeCase } from 'dashboard/composables/useTransformKeys';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import { conversationUrl, frontendURL } from '../../../helper/URLHelper';
import {
  ACCOUNT_EVENTS,
  CONVERSATION_EVENTS,
} from '../../../helper/AnalyticsHelper/events';
import MenuItem from '../../../components/widgets/conversation/contextMenu/menuItem.vue';
import { useTrack } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import ReportCaptainMessageDialog from './ReportCaptainMessageDialog.vue';

export default {
  components: {
    AddCannedModal,
    MenuItem,
    ContextMenu,
    NextButton,
    ReportCaptainMessageDialog,
  },
  props: {
    message: {
      type: Object,
      required: true,
    },
    isOpen: {
      type: Boolean,
      default: false,
    },
    enabledOptions: {
      type: Object,
      default: () => ({}),
    },
    contextMenuPosition: {
      type: Object,
      default: () => ({}),
    },
    hideButton: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['open', 'close', 'replyTo'],
  setup() {
    const { getPlainText } = useMessageFormatter();

    return {
      getPlainText,
    };
  },
  data() {
    return {
      isCannedResponseModalOpen: false,
      showDeleteModal: false,
      showEditModal: false,
      editedContent: '',
      isEditingMessage: false,
    };
  },
  computed: {
    ...mapGetters({
      getAccount: 'accounts/getAccount',
      currentAccountId: 'getCurrentAccountId',
      getUISettings: 'getUISettings',
      messageSignature: 'getMessageSignature',
    }),
    plainTextContent() {
      return this.getPlainText(this.messageContent);
    },
    conversationId() {
      return this.message.conversation_id ?? this.message.conversationId;
    },
    messageId() {
      return this.message.id;
    },
    messageContent() {
      return this.message.content;
    },
    contentAttributes() {
      return useSnakeCase(
        this.message.content_attributes ?? this.message.contentAttributes
      );
    },
    isPinned() {
      return !!(this.message.pinned_at ?? this.message.pinnedAt);
    },
    signatureRequired() {
      const account = this.getAccount(this.currentAccountId);
      return account?.settings?.signature_agents_can_disable !== true;
    },
    canSaveEdit() {
      const content = this.effectiveContent(this.editedContent);
      return (
        !!content && content !== this.effectiveContent(this.messageContent)
      );
    },
  },
  methods: {
    async copyLinkToMessage() {
      const fullConversationURL =
        window.chatwootConfig.hostURL +
        frontendURL(
          conversationUrl({
            id: this.conversationId,
            accountId: this.currentAccountId,
          })
        );
      await copyTextToClipboard(
        `${fullConversationURL}?messageId=${this.messageId}`
      );
      useAlert(this.$t('CONVERSATION.CONTEXT_MENU.LINK_COPIED'));
      this.handleClose();
    },
    async handleCopy() {
      await copyTextToClipboard(this.plainTextContent);
      useAlert(this.$t('CONTACT_PANEL.COPY_SUCCESSFUL'));
      this.handleClose();
    },
    showCannedResponseModal() {
      useTrack(ACCOUNT_EVENTS.ADDED_TO_CANNED_RESPONSE);
      this.isCannedResponseModalOpen = true;
    },
    hideCannedResponseModal() {
      this.isCannedResponseModalOpen = false;
      this.handleClose();
    },
    handleOpen(e) {
      this.$emit('open', e);
    },
    handleClose(e) {
      this.$emit('close', e);
    },
    async handleTranslate() {
      const { locale: accountLocale } = this.getAccount(this.currentAccountId);
      const agentLocale = this.getUISettings?.locale;
      const targetLanguage = agentLocale || accountLocale || 'en';
      try {
        await this.$store.dispatch('translateMessage', {
          conversationId: this.conversationId,
          messageId: this.messageId,
          targetLanguage,
        });
        useTrack(CONVERSATION_EVENTS.TRANSLATE_A_MESSAGE);
      } catch (error) {
        useAlert(parseAPIErrorResponse(error));
      }
      this.handleClose();
    },
    handleReplyTo() {
      this.$emit('replyTo', this.message);
      this.handleClose();
    },
    effectiveContent(content) {
      const cleaned = (content || '').trim();
      if (!this.signatureRequired) return cleaned;

      const signature = (this.messageSignature || '').trim();
      if (!signature || cleaned.endsWith(signature)) return cleaned;

      return [cleaned, signature].filter(Boolean).join('\n');
    },
    openEditModal() {
      this.editedContent = this.messageContent || '';
      this.showEditModal = true;
      this.handleClose();
    },
    closeEditModal() {
      this.showEditModal = false;
      this.editedContent = '';
    },
    async confirmEdit() {
      if (!this.canSaveEdit || this.isEditingMessage) return;
      this.isEditingMessage = true;
      try {
        await this.$store.dispatch('editMessage', {
          conversationId: this.conversationId,
          messageId: this.messageId,
          content: this.effectiveContent(this.editedContent),
        });
        useAlert(this.$t('CONVERSATION.CONTEXT_MENU.EDIT_SUCCESS'));
        this.closeEditModal();
      } catch (error) {
        useAlert(parseAPIErrorResponse(error));
      } finally {
        this.isEditingMessage = false;
      }
    },
    async handlePin() {
      try {
        await this.$store.dispatch('pinMessage', {
          conversationId: this.conversationId,
          messageId: this.messageId,
        });
        useAlert(this.$t('CONVERSATION.PINNED.PIN_SUCCESS'));
      } catch {
        useAlert(this.$t('CONVERSATION.PINNED.PIN_ERROR'));
      }
      this.handleClose();
    },
    async handleUnpin() {
      try {
        await this.$store.dispatch('unpinMessage', {
          conversationId: this.conversationId,
          messageId: this.messageId,
        });
        useAlert(this.$t('CONVERSATION.PINNED.UNPIN_SUCCESS'));
      } catch {
        useAlert(this.$t('CONVERSATION.PINNED.UNPIN_ERROR'));
      }
      this.handleClose();
    },
    openDeleteModal() {
      this.handleClose();
      this.showDeleteModal = true;
    },
    async confirmDeletion() {
      try {
        await this.$store.dispatch('deleteMessage', {
          conversationId: this.conversationId,
          messageId: this.messageId,
        });
        useAlert(this.$t('CONVERSATION.SUCCESS_DELETE_MESSAGE'));
        this.handleClose();
      } catch (error) {
        useAlert(this.$t('CONVERSATION.FAIL_DELETE_MESSSAGE'));
      }
    },
    closeDeleteModal() {
      this.showDeleteModal = false;
    },
    openReportDialog() {
      this.handleClose();
      this.$refs.reportDialog?.open();
    },
  },
};
</script>

<template>
  <div class="context-menu">
    <!-- Add To Canned Responses -->
    <woot-modal
      v-if="isCannedResponseModalOpen && enabledOptions['cannedResponse']"
      v-model:show="isCannedResponseModalOpen"
      :on-close="hideCannedResponseModal"
    >
      <AddCannedModal
        :response-content="plainTextContent"
        :on-close="hideCannedResponseModal"
      />
    </woot-modal>
    <!-- Edit Message -->
    <woot-modal
      v-if="showEditModal && enabledOptions['edit']"
      v-model:show="showEditModal"
      :on-close="closeEditModal"
    >
      <div class="edit-message-modal">
        <h2 class="mb-2 text-base font-medium">
          {{ $t('CONVERSATION.CONTEXT_MENU.EDIT_TITLE') }}
        </h2>
        <p class="mb-3 text-sm text-n-slate-11">
          {{ $t('CONVERSATION.CONTEXT_MENU.EDIT_DESCRIPTION') }}
        </p>
        <p
          v-if="signatureRequired"
          class="mb-3 text-xs font-medium text-n-amber-11"
        >
          {{ $t('CONVERSATION.CONTEXT_MENU.EDIT_SIGNATURE_REQUIRED') }}
        </p>
        <textarea
          v-model="editedContent"
          class="w-full min-h-28 p-3 text-sm border rounded-lg resize-y border-n-weak bg-n-background focus:outline-none focus:ring-2 focus:ring-n-brand"
          :placeholder="$t('CONVERSATION.CONTEXT_MENU.EDIT_PLACEHOLDER')"
          maxlength="150000"
        />
        <div class="flex justify-end gap-2 mt-4">
          <NextButton
            faded
            slate
            :label="$t('CONVERSATION.CONTEXT_MENU.EDIT_CANCEL')"
            @click="closeEditModal"
          />
          <NextButton
            :label="$t('CONVERSATION.CONTEXT_MENU.EDIT_SAVE')"
            :is-loading="isEditingMessage"
            :disabled="!canSaveEdit || isEditingMessage"
            @click="confirmEdit"
          />
        </div>
      </div>
    </woot-modal>
    <!-- Confirm Deletion -->
    <woot-delete-modal
      v-if="showDeleteModal && enabledOptions['delete']"
      v-model:show="showDeleteModal"
      class="context-menu--delete-modal"
      :on-close="closeDeleteModal"
      :on-confirm="confirmDeletion"
      :title="$t('CONVERSATION.CONTEXT_MENU.DELETE_CONFIRMATION.TITLE')"
      :message="$t('CONVERSATION.CONTEXT_MENU.DELETE_CONFIRMATION.MESSAGE')"
      :confirm-text="$t('CONVERSATION.CONTEXT_MENU.DELETE_CONFIRMATION.DELETE')"
      :reject-text="$t('CONVERSATION.CONTEXT_MENU.DELETE_CONFIRMATION.CANCEL')"
    />
    <NextButton
      v-if="!hideButton"
      ghost
      slate
      sm
      icon="i-lucide-ellipsis-vertical"
      class="invisible group-hover/context-menu:visible"
      @click="handleOpen"
    />
    <ContextMenu
      v-if="isOpen && !isCannedResponseModalOpen"
      :x="contextMenuPosition.x"
      :y="contextMenuPosition.y"
      @close="handleClose"
    >
      <div class="menu-container">
        <MenuItem
          v-if="enabledOptions['replyTo']"
          :option="{
            icon: 'arrow-reply',
            label: $t('CONVERSATION.CONTEXT_MENU.REPLY_TO'),
          }"
          variant="icon"
          @click.stop="handleReplyTo"
        />
        <MenuItem
          v-if="enabledOptions['pin']"
          :option="{
            icon: 'pin',
            label: $t('CONVERSATION.CONTEXT_MENU.PIN'),
          }"
          variant="icon"
          @click.stop="handlePin"
        />
        <MenuItem
          v-if="enabledOptions['unpin']"
          :option="{
            icon: 'pin',
            label: $t('CONVERSATION.CONTEXT_MENU.UNPIN'),
          }"
          variant="icon"
          @click.stop="handleUnpin"
        />
        <MenuItem
          v-if="enabledOptions['edit']"
          :option="{
            icon: 'edit',
            label: $t('CONVERSATION.CONTEXT_MENU.EDIT'),
          }"
          variant="icon"
          @click.stop="openEditModal"
        />
        <MenuItem
          v-if="enabledOptions['copy']"
          :option="{
            icon: 'clipboard',
            label: $t('CONVERSATION.CONTEXT_MENU.COPY'),
          }"
          variant="icon"
          @click.stop="handleCopy"
        />
        <MenuItem
          v-if="enabledOptions['translate']"
          :option="{
            icon: 'translate',
            label: $t('CONVERSATION.CONTEXT_MENU.TRANSLATE'),
          }"
          variant="icon"
          @click.stop="handleTranslate"
        />
        <hr />
        <MenuItem
          v-if="enabledOptions['copyLink']"
          :option="{
            icon: 'link',
            label: $t('CONVERSATION.CONTEXT_MENU.COPY_PERMALINK'),
          }"
          variant="icon"
          @click.stop="copyLinkToMessage"
        />
        <MenuItem
          v-if="enabledOptions['cannedResponse']"
          :option="{
            icon: 'comment-add',
            label: $t('CONVERSATION.CONTEXT_MENU.CREATE_A_CANNED_RESPONSE'),
          }"
          variant="icon"
          @click.stop="showCannedResponseModal"
        />
        <hr v-if="enabledOptions['report']" />
        <MenuItem
          v-if="enabledOptions['report']"
          :option="{
            icon: 'warning',
            label: $t('CONVERSATION.CONTEXT_MENU.REPORT_MESSAGE.LABEL'),
          }"
          variant="icon"
          @click.stop="openReportDialog"
        />
        <hr v-if="enabledOptions['delete']" />
        <MenuItem
          v-if="enabledOptions['delete']"
          :option="{
            icon: 'delete',
            label: $t('CONVERSATION.CONTEXT_MENU.DELETE'),
          }"
          variant="icon"
          @click.stop="openDeleteModal"
        />
      </div>
    </ContextMenu>
    <ReportCaptainMessageDialog
      v-if="enabledOptions['report']"
      ref="reportDialog"
      :message-id="messageId"
    />
  </div>
</template>

<style lang="scss" scoped>
.menu-container {
  @apply p-1 bg-n-background shadow-xl rounded-md;

  hr:first-child {
    @apply hidden;
  }

  hr {
    @apply m-1 border-b border-solid border-n-strong;
  }
}

.edit-message-modal {
  @apply p-6;

  textarea {
    @apply outline-none;
  }
}

.context-menu--delete-modal {
  :deep(.modal-container) {
    @apply max-w-[30rem];

    h2 {
      @apply font-medium text-base;
    }
  }
}
</style>
