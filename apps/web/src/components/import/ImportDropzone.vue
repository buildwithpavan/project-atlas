<script setup lang="ts">
/* eslint-disable no-undef */
import { ref } from 'vue'

const emit = defineEmits<{
  select: [file: File]
}>()

defineProps<{
  disabled?: boolean
}>()

const dragActive = ref(false)
const fileInput = ref<HTMLInputElement | null>(null)

const ACCEPTED_TYPE = '.csv'

function openPicker() {
  fileInput.value?.click()
}

function onFileChange(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (file) {
    emit('select', file)
  }
  // Reset so the same file can be re-selected
  input.value = ''
}

function onDragEnter(e: DragEvent) {
  e.preventDefault()
  dragActive.value = true
}

function onDragOver(e: DragEvent) {
  e.preventDefault()
  dragActive.value = true
}

function onDragLeave(e: DragEvent) {
  e.preventDefault()
  // Only deactivate when leaving the dropzone itself
  const related = e.relatedTarget as Node | null
  const target = e.currentTarget as HTMLElement
  if (!related || !target.contains(related)) {
    dragActive.value = false
  }
}

function onDrop(e: DragEvent) {
  e.preventDefault()
  dragActive.value = false
  const file = e.dataTransfer?.files[0]
  if (file) {
    emit('select', file)
  }
}
</script>

<template>
  <div
    class="relative rounded-atlas-md border-2 border-dashed transition-colors cursor-pointer"
    :class="[
      dragActive
        ? 'border-atlas-brand bg-atlas-brand-subtle'
        : 'border-atlas-border hover:border-atlas-text-muted',
      disabled ? 'opacity-60 pointer-events-none' : '',
    ]"
    role="button"
    tabindex="0"
    :aria-label="dragActive ? 'Drop your CSV file here' : 'Upload area. Click or drag a CSV file to upload'"
    @click="openPicker"
    @keydown.enter="openPicker"
    @keydown.space.prevent="openPicker"
    @dragenter="onDragEnter"
    @dragover="onDragOver"
    @dragleave="onDragLeave"
    @drop="onDrop"
  >
    <div class="flex flex-col items-center justify-center px-6 py-12 text-center">
      <!-- Upload icon -->
      <div class="size-12 rounded-full bg-atlas-brand-subtle flex items-center justify-center mb-4">
        <svg
          class="size-6 text-atlas-brand"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="1.5"
          aria-hidden="true"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5"
          />
        </svg>
      </div>

      <p class="text-sm font-medium text-atlas-text-primary">
        <span v-if="dragActive">Drop your CSV file here</span>
        <span v-else>Drag and drop your CSV file here</span>
      </p>
      <p class="mt-1 text-xs text-atlas-text-muted">
        or
      </p>
      <button
        type="button"
        class="atlas-focus-ring mt-2 inline-flex items-center rounded-atlas px-4 py-2 text-sm font-medium text-atlas-brand hover:bg-atlas-brand-subtle transition-colors"
        :disabled="disabled"
        @click.stop="openPicker"
      >
        Choose CSV file
      </button>
      <p class="mt-3 text-xs text-atlas-text-muted">
        CSV files only
      </p>
    </div>

    <input
      ref="fileInput"
      type="file"
      :accept="ACCEPTED_TYPE"
      class="sr-only"
      aria-label="Choose CSV file to upload"
      @change="onFileChange"
    >
  </div>
</template>
