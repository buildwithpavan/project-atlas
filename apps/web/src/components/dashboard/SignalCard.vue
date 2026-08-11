<script setup lang="ts">
defineProps<{
  label: string
  value: number
  description: string
  variant: 'feature' | 'bug'
  loading?: boolean
}>()
</script>

<template>
  <div class="bg-atlas-surface border border-atlas-border rounded-atlas-lg shadow-atlas-sm p-5">
    <div class="flex items-start gap-3">
      <!-- Icon -->
      <span
        class="inline-flex items-center justify-center size-9 rounded-atlas-md shrink-0"
        :class="variant === 'feature' ? 'bg-atlas-accent-subtle' : 'bg-atlas-error-subtle'"
        aria-hidden="true"
      >
        <svg
          v-if="variant === 'feature'"
          class="size-5 text-atlas-accent"
          viewBox="0 0 20 20"
          fill="currentColor"
        >
          <path
            fill-rule="evenodd"
            d="M10 2a1 1 0 011 1v1.323l3.954 1.582 1.599-.8a1 1 0 01.894 1.79l-1.233.616 1.738 5.42a1 1 0 01-.285 1.05A3.989 3.989 0 0115 15a3.989 3.989 0 01-2.667-1.019 1 1 0 01-.285-1.05l1.715-5.349L11 6.477V16h2a1 1 0 110 2H7a1 1 0 110-2h2V6.477L6.237 7.582l1.715 5.349a1 1 0 01-.285 1.05A3.989 3.989 0 015 15a3.989 3.989 0 01-2.667-1.019 1 1 0 01-.285-1.05l1.738-5.42-1.233-.617a1 1 0 01.894-1.788l1.599.799L9 4.323V3a1 1 0 011-1z"
            clip-rule="evenodd"
          />
        </svg>
        <svg
          v-else
          class="size-5 text-atlas-error"
          viewBox="0 0 20 20"
          fill="currentColor"
        >
          <path
            fill-rule="evenodd"
            d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z"
            clip-rule="evenodd"
          />
        </svg>
      </span>

      <div class="min-w-0 flex-1">
        <p class="text-sm font-medium text-atlas-text-secondary">
          {{ label }}
        </p>
        <template v-if="loading">
          <div class="mt-2 h-7 w-12 animate-pulse rounded bg-atlas-surface-muted" />
        </template>
        <template v-else>
          <p class="mt-1 text-2xl font-semibold text-atlas-text-primary tabular-nums">
            {{ value }}
          </p>
          <p class="mt-0.5 text-sm text-atlas-text-muted">
            {{ description }}
          </p>
        </template>
      </div>
    </div>
  </div>
</template>
