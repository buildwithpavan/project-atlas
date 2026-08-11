<script setup lang="ts">
import { computed } from 'vue'

const props = defineProps<{
  title: string
  distribution: Record<string, number>
  loading?: boolean
}>()

interface Entry {
  label: string
  count: number
  percentage: number
}

const entries = computed<Entry[]>(() => {
  const items = Object.entries(props.distribution)
  if (items.length === 0) return []

  const max = Math.max(...items.map(([, v]) => v))
  return items
    .sort(([, a], [, b]) => b - a)
    .map(([label, count]) => ({
      label,
      count,
      percentage: max > 0 ? (count / max) * 100 : 0,
    }))
})

const isEmpty = computed(() => entries.value.length === 0)
</script>

<template>
  <div class="bg-atlas-surface border border-atlas-border rounded-atlas-lg shadow-atlas-sm p-5">
    <h3 class="text-sm font-medium text-atlas-text-secondary">
      {{ title }}
    </h3>

    <template v-if="loading">
      <div class="mt-4 space-y-3">
        <div
          v-for="i in 4"
          :key="i"
          class="flex items-center gap-3"
        >
          <div class="h-4 w-20 animate-pulse rounded bg-atlas-surface-muted" />
          <div class="h-3 flex-1 animate-pulse rounded bg-atlas-surface-muted" />
        </div>
      </div>
    </template>

    <template v-else-if="isEmpty">
      <p class="mt-4 text-sm text-atlas-text-muted">
        No data available.
      </p>
    </template>

    <template v-else>
      <div
        class="mt-4 space-y-3"
        role="list"
        :aria-label="title"
      >
        <div
          v-for="entry in entries"
          :key="entry.label"
          role="listitem"
        >
          <div class="flex items-baseline justify-between gap-2 mb-1">
            <span class="text-sm text-atlas-text-primary capitalize">
              {{ entry.label }}
            </span>
            <span class="text-sm tabular-nums text-atlas-text-muted shrink-0">
              {{ entry.count }}
            </span>
          </div>
          <div
            class="h-2 w-full rounded-atlas-full bg-atlas-surface-muted overflow-hidden"
            role="progressbar"
            :aria-valuenow="entry.count"
            :aria-label="`${entry.label}: ${entry.count}`"
          >
            <div
              class="h-full rounded-atlas-full bg-atlas-accent transition-all"
              :style="{ width: `${entry.percentage}%` }"
            />
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
