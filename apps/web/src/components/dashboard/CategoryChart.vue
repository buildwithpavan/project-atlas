<script setup lang="ts">
import { computed } from 'vue'

const props = defineProps<{
  categories: Record<string, number>
  loading?: boolean
}>()

interface CategoryEntry {
  name: string
  count: number
  percentage: number
}

const entries = computed<CategoryEntry[]>(() => {
  const items = Object.entries(props.categories)
  if (items.length === 0) return []

  const max = Math.max(...items.map(([, v]) => v))
  return items
    .sort(([, a], [, b]) => b - a)
    .slice(0, 8)
    .map(([name, count]) => ({
      name,
      count,
      percentage: max > 0 ? (count / max) * 100 : 0,
    }))
})

const isEmpty = computed(() => entries.value.length === 0)
</script>

<template>
  <div class="bg-voceive-surface border border-voceive-border rounded-voceive-lg shadow-voceive-sm p-5">
    <h3 class="text-sm font-medium text-voceive-text-secondary">
      What Customers Are Talking About
    </h3>

    <!-- Loading -->
    <template v-if="loading">
      <div class="mt-4 space-y-3">
        <div
          v-for="i in 4"
          :key="i"
          class="flex items-center gap-3"
        >
          <div class="h-4 w-24 animate-pulse rounded bg-voceive-surface-muted" />
          <div class="h-3 flex-1 animate-pulse rounded bg-voceive-surface-muted" />
        </div>
      </div>
    </template>

    <!-- Empty -->
    <template v-else-if="isEmpty">
      <p class="mt-4 text-sm text-voceive-text-muted">
        No category data yet. Categories are extracted during ticket analysis.
      </p>
    </template>

    <!-- Chart -->
    <template v-else>
      <div
        class="mt-4 space-y-3"
        role="list"
        aria-label="Top customer topics"
      >
        <div
          v-for="entry in entries"
          :key="entry.name"
          class="group"
          role="listitem"
        >
          <div class="flex items-baseline justify-between gap-2 mb-1">
            <span class="text-sm text-voceive-text-primary capitalize truncate">
              {{ entry.name }}
            </span>
            <span class="text-sm tabular-nums text-voceive-text-muted shrink-0">
              {{ entry.count }}
            </span>
          </div>
          <div
            class="h-2 w-full rounded-voceive-full bg-voceive-surface-muted overflow-hidden"
            role="progressbar"
            :aria-valuenow="entry.count"
            :aria-label="`${entry.name}: ${entry.count} tickets`"
          >
            <div
              class="h-full rounded-voceive-full bg-voceive-brand transition-all"
              :style="{ width: `${entry.percentage}%` }"
            />
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
