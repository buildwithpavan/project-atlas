<script setup lang="ts">
import { AButton } from '@/components/ui'

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
    class="flex flex-col items-center justify-center py-16 text-center"
  >
    <div class="size-16 rounded-full bg-atlas-error-subtle flex items-center justify-center mb-4">
      <svg
        class="size-8 text-atlas-error"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="1.5"
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
      Unable to load report
    </h2>
    <p class="mt-2 max-w-sm text-sm text-atlas-text-muted">
      {{ message || 'Something went wrong while generating your report. Please try again.' }}
    </p>
    <AButton
      variant="secondary"
      size="md"
      class="mt-4"
      @click="$emit('retry')"
    >
      Try again
    </AButton>
  </div>
</template>
