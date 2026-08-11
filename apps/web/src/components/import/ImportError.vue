<script setup lang="ts">
defineProps<{
  message?: string
}>()

defineEmits<{
  retry: []
}>()
</script>

<template>
  <div
    role="alert"
    class="flex flex-col items-center justify-center py-8 text-center"
  >
    <!-- Error icon -->
    <div class="size-14 rounded-full bg-atlas-error/10 flex items-center justify-center mb-4">
      <svg
        class="size-7 text-atlas-error"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        aria-hidden="true"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z"
        />
      </svg>
    </div>

    <h2 class="text-lg font-semibold text-atlas-text-primary">
      Upload failed
    </h2>
    <p class="mt-2 max-w-md text-sm text-atlas-text-muted">
      {{ message || "Atlas couldn't process this file. Please check the CSV format and try again." }}
    </p>

    <button
      type="button"
      class="atlas-focus-ring mt-6 inline-flex items-center rounded-atlas px-4 py-2 text-sm font-medium bg-atlas-brand text-white hover:bg-atlas-brand-hover transition-colors"
      @click="$emit('retry')"
    >
      Try again
    </button>
  </div>
</template>
