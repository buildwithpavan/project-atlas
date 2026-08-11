<script setup lang="ts">
import type { Upload } from '@/api/types'

defineProps<{
  upload: Upload
}>()
</script>

<template>
  <div class="flex flex-col items-center justify-center py-8 text-center">
    <!-- Spinner icon -->
    <div class="size-14 rounded-full bg-atlas-brand-subtle flex items-center justify-center mb-4">
      <svg
        class="size-7 text-atlas-brand animate-spin"
        viewBox="0 0 24 24"
        fill="none"
        aria-hidden="true"
      >
        <circle
          class="opacity-25"
          cx="12"
          cy="12"
          r="10"
          stroke="currentColor"
          stroke-width="4"
        />
        <path
          class="opacity-75"
          fill="currentColor"
          d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
        />
      </svg>
    </div>

    <h2 class="text-lg font-semibold text-atlas-text-primary">
      Processing your data
    </h2>
    <p class="mt-2 max-w-md text-sm text-atlas-text-muted">
      Atlas is processing <strong class="text-atlas-text-primary">{{ upload.filename }}</strong>.
      Customer conversations will be analyzed for sentiment, categories, and actionable insights.
    </p>
    <p class="mt-1 text-xs text-atlas-text-muted">
      This may take a few moments.
    </p>

    <div class="mt-6 flex flex-col sm:flex-row gap-3">
      <RouterLink
        to="/app/dashboard"
        class="atlas-focus-ring inline-flex items-center justify-center rounded-atlas px-4 py-2 text-sm font-medium bg-atlas-brand text-white hover:bg-atlas-brand-hover transition-colors"
      >
        View Dashboard
      </RouterLink>
      <RouterLink
        to="/app/tickets"
        class="atlas-focus-ring inline-flex items-center justify-center rounded-atlas px-4 py-2 text-sm font-medium border border-atlas-border bg-atlas-surface text-atlas-text-primary hover:bg-atlas-surface-muted transition-colors"
      >
        View Tickets
      </RouterLink>
    </div>
  </div>
</template>
