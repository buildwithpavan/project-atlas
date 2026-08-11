<script setup lang="ts">
defineProps<{
  filename: string
  size: number
}>()

defineEmits<{
  remove: []
}>()

function formatSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
}
</script>

<template>
  <div class="flex items-center gap-3 rounded-atlas border border-atlas-border bg-atlas-surface px-4 py-3">
    <!-- CSV icon -->
    <div class="flex-shrink-0 size-10 rounded-atlas bg-atlas-brand-subtle flex items-center justify-center">
      <svg
        class="size-5 text-atlas-brand"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="1.5"
        aria-hidden="true"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z"
        />
      </svg>
    </div>

    <!-- File details -->
    <div class="min-w-0 flex-1">
      <p class="truncate text-sm font-medium text-atlas-text-primary">
        {{ filename }}
      </p>
      <p class="text-xs text-atlas-text-muted">
        {{ formatSize(size) }}
      </p>
    </div>

    <!-- Remove button -->
    <button
      type="button"
      class="atlas-focus-ring flex-shrink-0 rounded-atlas p-1.5 text-atlas-text-muted hover:bg-atlas-surface-muted hover:text-atlas-text-primary transition-colors"
      aria-label="Remove selected file"
      @click="$emit('remove')"
    >
      <svg
        class="size-4"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        aria-hidden="true"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M6 18L18 6M6 6l12 12"
        />
      </svg>
    </button>
  </div>
</template>
