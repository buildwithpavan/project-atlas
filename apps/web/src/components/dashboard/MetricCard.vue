<script setup lang="ts">
defineProps<{
  label: string
  value: string | number
  description?: string
  loading?: boolean
}>()
</script>

<template>
  <div class="bg-atlas-surface border border-atlas-border rounded-atlas-lg shadow-atlas-sm p-5">
    <p class="text-sm font-medium text-atlas-text-secondary">
      {{ label }}
    </p>
    <template v-if="loading">
      <div
        class="mt-2 h-8 w-20 animate-pulse rounded-atlas bg-atlas-surface-muted"
        aria-hidden="true"
      />
      <div
        class="mt-2 h-4 w-32 animate-pulse rounded-atlas bg-atlas-surface-muted"
        aria-hidden="true"
      />
    </template>
    <template v-else>
      <p class="mt-2 text-3xl font-semibold text-atlas-text-primary tracking-tight">
        {{ value }}
      </p>
      <p
        v-if="description"
        class="mt-1 text-sm text-atlas-text-muted"
      >
        {{ description }}
      </p>
    </template>
  </div>
</template>
