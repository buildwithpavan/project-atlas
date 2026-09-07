<script setup lang="ts">
import type { Upload } from '@/api/types'

defineProps<{
  upload: Upload
}>()
</script>

<template>
  <div class="flex flex-col items-center justify-center py-8 text-center">
    <!-- Success icon -->
    <div class="size-14 rounded-full bg-voceive-success/10 flex items-center justify-center mb-4">
      <svg
        class="size-7 text-voceive-success"
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

    <h2 class="text-lg font-semibold text-voceive-text-primary">
      Import started
    </h2>
    <p class="mt-2 max-w-md text-sm text-voceive-text-muted">
      <strong class="text-voceive-text-primary">{{ upload.filename }}</strong> was accepted.
      Voceive is analyzing your customer conversations — insights will appear on your dashboard and reports as analysis completes.
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
