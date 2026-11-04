<script setup>
import { computed, defineAsyncComponent, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { vOnClickOutside } from '@vueuse/components';
import Button from 'dashboard/components-next/button/Button.vue';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import { MESSAGE_VARIABLES } from 'shared/constants/messages';

const props = defineProps({
  modelValue: { type: String, default: '' },
  placeholder: { type: String, default: '' },
  hasError: { type: Boolean, default: false },
});

const emit = defineEmits(['update:modelValue', 'blur']);

const EmojiIconPicker = defineAsyncComponent(
  () =>
    import('dashboard/components-next/emoji-icon-picker/EmojiIconPicker.vue')
);

const { t } = useI18n();
const editorRef = ref(null);
const showEmojiPicker = ref(false);
const showVariables = ref(false);

const AVAILABLE_VARIABLES = [
  'greeting',
  'contact.name',
  'contact.first_name',
  'contact.last_name',
  'contact.email',
  'contact.phone',
  'conversation.id',
  'agent.name',
  'inbox.name',
];

const variables = computed(() =>
  MESSAGE_VARIABLES.filter(variable =>
    AVAILABLE_VARIABLES.includes(variable.key)
  )
);

const editorValue = computed({
  get: () => props.modelValue,
  set: value => emit('update:modelValue', value),
});

const closePickers = () => {
  showEmojiPicker.value = false;
  showVariables.value = false;
};

const insertText = text => {
  editorRef.value?.insertText(text);
  closePickers();
};

const insertEmoji = payload => insertText(payload.value);
const insertVariable = variable => insertText(`{{${variable.key}}}`);
const variablePlaceholder = key => `{{${key}}}`;
</script>

<template>
  <div class="relative">
    <div class="absolute z-20 flex gap-1 top-2 ltr:right-2 rtl:left-2">
      <div
        v-on-click-outside="() => (showEmojiPicker = false)"
        class="relative"
      >
        <Button
          v-tooltip.top="t('CANNED_MGMT.EDITOR.EMOJI')"
          type="button"
          variant="ghost"
          color="slate"
          size="sm"
          icon="i-lucide-smile-plus"
          @click="showEmojiPicker = !showEmojiPicker"
        />
        <EmojiIconPicker
          v-if="showEmojiPicker"
          mode="emoji"
          class="mt-1 !top-full ltr:right-0 rtl:left-0"
          @select="insertEmoji"
        />
      </div>

      <div v-on-click-outside="() => (showVariables = false)" class="relative">
        <Button
          v-tooltip.top="t('CANNED_MGMT.EDITOR.VARIABLES')"
          type="button"
          variant="ghost"
          color="slate"
          size="sm"
          icon="i-lucide-braces"
          @click="showVariables = !showVariables"
        />
        <div
          v-if="showVariables"
          class="absolute z-30 w-72 mt-1 overflow-y-auto border shadow-xl ltr:right-0 rtl:left-0 max-h-72 rounded-xl border-n-weak bg-n-surface-2"
        >
          <button
            v-for="variable in variables"
            :key="variable.key"
            type="button"
            class="flex flex-col w-full gap-0.5 px-3 py-2 text-left border-0 hover:bg-n-alpha-black2"
            @click="insertVariable(variable)"
          >
            <span class="text-sm font-medium text-n-slate-12">
              {{ variable.label }}
            </span>
            <code class="text-xs text-n-slate-10">
              {{ variablePlaceholder(variable.key) }}
            </code>
          </button>
        </div>
      </div>
    </div>

    <WootMessageEditor
      ref="editorRef"
      v-model="editorValue"
      class="message-editor [&>div]:px-1"
      :class="{ editor_warning: hasError }"
      channel-type="Context::Default"
      enable-variables
      :enable-canned-responses="false"
      :placeholder="placeholder"
      @blur="emit('blur')"
    />
  </div>
</template>

<style scoped lang="scss">
:deep(.ProseMirror-menubar) {
  @apply hidden;
}

:deep(.ProseMirror-woot-style) {
  @apply min-h-[12.5rem] pt-10;
}
</style>
