<script setup lang="ts">
import type { Upload } from '@/api/types'

defineProps<{
  upload: Upload
}>()
</script>

<template>
  <div class="flex flex-col items-center justify-center py-8 text-center">
    <!-- Spinner icon -->
    <div class="size-14 rounded-full bg-voceive-brand-subtle flex items-center justify-center mb-4">
      <svg
        class="size-7 text-voceive-brand animate-spin"
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

    <h2 class="text-lg font-semibold text-voceive-text-primary">
      Processing your data
    </h2>
    <p class="mt-2 max-w-md text-sm text-voceive-text-muted">
      Voceive is processing <strong class="text-voceive-text-primary">{{ upload.filename }}</strong>.
      Customer conversations will be analyzed for sentiment, categories, and actionable insights.
    </p>
    <p class="mt-1 text-xs text-voceive-text-muted">
      This may take a few moments.
    </p>

    <div class="mt-6 flex flex-col sm:flex-row gap-3">
      <RouterLink
        to="/app/dashboard"
        class="voceive-focus-ring inline-flex items-center justify-center rounded-voceive px-4 py-2 text-sm font-medium bg-voceive-brand text-white hover:bg-voceive-brand-hover transition-colors"
      >
        View Dashboard
      </RouterLink>
      <RouterLink
        to="/app/tickets"
        class="voceive-focus-ring inline-flex items-center justify-center rounded-voceive px-4 py-2 text-sm font-medium border border-voceive-border bg-voceive-surface text-voceive-text-primary hover:bg-voceive-surface-muted transition-colors"
      >
        View Tickets
      </RouterLink>
    </div>
  </div>
</template>
