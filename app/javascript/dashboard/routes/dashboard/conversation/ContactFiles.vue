<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { formatBytes } from 'shared/helpers/FileHelper';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import FileIcon from 'next/icon/FileIcon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  contactId: {
    type: [Number, String],
    default: null,
  },
});

const { t } = useI18n();
const store = useStore();
const contactFilesGetter = useMapGetter('contacts/getContactFiles');

const files = computed(() => contactFilesGetter.value(props.contactId));
const isLoading = ref(false);
const isUploading = ref(false);
const fileInput = ref(null);
const dialogRef = ref(null);
const selectedFile = ref(null);

const loadFiles = async () => {
  if (!props.contactId) return;

  isLoading.value = true;
  try {
    await store.dispatch('contacts/fetchContactFiles', props.contactId);
  } catch (error) {
    useAlert(t('CONVERSATION_SIDEBAR.CONTACT_FILES.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const openFilePicker = () => fileInput.value?.click();

const onFilesSelected = async event => {
  const selectedFiles = Array.from(event.target.files || []);
  event.target.value = '';
  if (!selectedFiles.length) return;

  isUploading.value = true;
  try {
    await store.dispatch('contacts/uploadContactFiles', {
      id: props.contactId,
      files: selectedFiles,
    });
    useAlert(t('CONVERSATION_SIDEBAR.CONTACT_FILES.UPLOAD_SUCCESS'));
  } catch (error) {
    useAlert(
      error?.response?.data?.error ||
        t('CONVERSATION_SIDEBAR.CONTACT_FILES.UPLOAD_ERROR')
    );
  } finally {
    isUploading.value = false;
  }
};

const openFile = file => {
  if (file.data_url) {
    window.open(file.data_url, '_blank', 'noopener,noreferrer');
  }
};

const askDelete = file => {
  selectedFile.value = file;
  dialogRef.value?.open();
};

const confirmDelete = async () => {
  if (!selectedFile.value) return;

  try {
    await store.dispatch('contacts/deleteContactFile', {
      id: props.contactId,
      fileId: selectedFile.value.id,
    });
    useAlert(t('CONVERSATION_SIDEBAR.CONTACT_FILES.DELETE_SUCCESS'));
  } catch (error) {
    useAlert(t('CONVERSATION_SIDEBAR.CONTACT_FILES.DELETE_ERROR'));
  } finally {
    selectedFile.value = null;
    dialogRef.value?.close();
  }
};

watch(
  () => props.contactId,
  id => {
    if (id) loadFiles();
  },
  { immediate: true }
);
</script>

<template>
  <div class="px-2">
    <div class="flex items-center justify-between gap-2 px-1 pb-2">
      <span class="text-xs text-n-slate-11">
        {{ t('CONVERSATION_SIDEBAR.CONTACT_FILES.HINT') }}
      </span>
      <NextButton
        ghost
        slate
        sm
        icon="i-lucide-upload"
        :label="t('CONVERSATION_SIDEBAR.CONTACT_FILES.ADD')"
        :is-loading="isUploading"
        @click="openFilePicker"
      />
      <input
        ref="fileInput"
        type="file"
        multiple
        class="hidden"
        @change="onFilesSelected"
      />
    </div>

    <div v-if="isLoading" class="flex justify-center p-3">
      <Spinner class="size-5" />
    </div>
    <p
      v-else-if="!files.length"
      class="p-3 text-sm text-center text-n-slate-11"
    >
      {{ t('CONVERSATION_SIDEBAR.CONTACT_FILES.EMPTY') }}
    </p>
    <ul v-else class="flex flex-col gap-0.5">
      <li
        v-for="file in files"
        :key="file.id"
        role="button"
        tabindex="0"
        class="flex items-center gap-3 px-2 py-2 transition-colors rounded-lg cursor-pointer hover:bg-n-slate-3 group focus:outline-none focus-visible:ring-2 focus-visible:ring-n-blue-9"
        @click="openFile(file)"
        @keydown.enter="openFile(file)"
        @keydown.space.prevent="openFile(file)"
      >
        <div
          class="flex items-center justify-center overflow-hidden rounded-lg size-9 shrink-0 bg-gradient-to-br from-n-slate-3 to-n-slate-4 ring-1 ring-inset ring-n-slate-4/40"
        >
          <img
            v-if="file.file_type === 'image'"
            :src="file.thumb_url || file.data_url"
            :alt="file.filename"
            class="object-cover w-full h-full"
          />
          <FileIcon
            v-else
            :file-type="file.extension?.toLowerCase() || ''"
            class="size-4 text-n-slate-11"
          />
        </div>
        <div class="flex-1 min-w-0">
          <p class="mb-1 text-sm font-medium truncate text-n-slate-12">
            {{ file.filename }}
          </p>
          <p class="text-xs text-n-slate-11">
            {{ formatBytes(file.file_size) }}
          </p>
        </div>
        <NextButton
          ghost
          ruby
          sm
          icon="i-lucide-trash-2"
          class="opacity-0 group-hover:opacity-100"
          :aria-label="t('CONVERSATION_SIDEBAR.CONTACT_FILES.DELETE')"
          @click.stop="askDelete(file)"
          @keydown.enter.stop
          @keydown.space.stop
        />
      </li>
    </ul>

    <Dialog
      ref="dialogRef"
      type="alert"
      :title="t('CONVERSATION_SIDEBAR.CONTACT_FILES.DELETE_CONFIRM.TITLE')"
      :description="
        t('CONVERSATION_SIDEBAR.CONTACT_FILES.DELETE_CONFIRM.DESCRIPTION')
      "
      :confirm-button-label="
        t('CONVERSATION_SIDEBAR.CONTACT_FILES.DELETE_CONFIRM.CONFIRM')
      "
      :cancel-button-label="
        t('CONVERSATION_SIDEBAR.CONTACT_FILES.DELETE_CONFIRM.CANCEL')
      "
      @confirm="confirmDelete"
    />
  </div>
</template>
