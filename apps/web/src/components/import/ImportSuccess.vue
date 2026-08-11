<script setup lang="ts">
import type { Upload } from '@/api/types'

defineProps<{
  upload: Upload
}>()
</script>

<template>
  <div class="flex flex-col items-center justify-center py-8 text-center">
    <!-- Success icon -->
    <div class="size-14 rounded-full bg-atlas-success/10 flex items-center justify-center mb-4">
      <svg
        class="size-7 text-atlas-success"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        aria-hidden="true"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
        />
      </svg>
    </div>

    <h2 class="text-lg font-semibold text-atlas-text-primary">
      Import started
    </h2>
    <p class="mt-2 max-w-md text-sm text-atlas-text-muted">
      <strong class="text-atlas-text-primary">{{ upload.filename }}</strong> was accepted.
      Atlas is analyzing your customer conversations — insights will appear on your dashboard and reports as analysis completes.
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
