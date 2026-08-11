<script setup lang="ts">
import { computed } from 'vue'

const props = defineProps<{
  distribution: Record<string, number>
  loading?: boolean
}>()

interface Segment {
  label: string
  count: number
  percentage: number
  color: string
  offset: number
}

const sentimentColors: Record<string, string> = {
  positive: 'var(--atlas-success)',
  neutral: 'var(--atlas-chart-3)',
  negative: 'var(--atlas-error)',
  mixed: 'var(--atlas-chart-5)',
}

const sentimentBgClasses: Record<string, string> = {
  positive: 'bg-atlas-success',
  neutral: 'bg-atlas-chart-3',
  negative: 'bg-atlas-error',
  mixed: 'bg-atlas-chart-5',
}

const segments = computed<Segment[]>(() => {
  const entries = Object.entries(props.distribution)
  const total = entries.reduce((sum, [, v]) => sum + v, 0)
  if (total === 0) return []

  let offset = 0
  return entries
    .filter(([, v]) => v > 0)
    .map(([label, count]) => {
      const percentage = (count / total) * 100
      const seg: Segment = {
        label,
        count,
        percentage,
        color: sentimentColors[label] ?? 'var(--atlas-chart-6)',
        offset,
      }
      offset += percentage
      return seg
    })
})

const total = computed(() =>
  Object.values(props.distribution).reduce((s, v) => s + v, 0),
)

const isEmpty = computed(() => total.value === 0)
</script>

<template>
  <div class="bg-atlas-surface border border-atlas-border rounded-atlas-lg shadow-atlas-sm p-5">
    <h3 class="text-sm font-medium text-atlas-text-secondary">
      Customer Sentiment
    </h3>

    <!-- Loading -->
    <template v-if="loading">
      <div class="mt-6 flex items-center justify-center gap-8">
        <div class="size-36 animate-pulse rounded-full bg-atlas-surface-muted" />
        <div class="space-y-3">
          <div class="h-4 w-24 animate-pulse rounded bg-atlas-surface-muted" />
          <div class="h-4 w-20 animate-pulse rounded bg-atlas-surface-muted" />
          <div class="h-4 w-16 animate-pulse rounded bg-atlas-surface-muted" />
        </div>
      </div>
    </template>

    <!-- Empty -->
    <template v-else-if="isEmpty">
      <p class="mt-4 text-sm text-atlas-text-muted">
        No sentiment data available yet. Sentiment analysis requires analyzed tickets.
      </p>
    </template>

    <!-- Chart -->
    <template v-else>
      <div class="mt-4 flex flex-col sm:flex-row items-center gap-6">
        <!-- Donut -->
        <div class="relative shrink-0">
          <svg
            viewBox="0 0 36 36"
            class="size-36"
            role="img"
            :aria-label="`Sentiment distribution: ${segments.map(s => `${s.label} ${Math.round(s.percentage)}%`).join(', ')}`"
          >
            <circle
              cx="18"
              cy="18"
              r="15.915"
              fill="none"
              class="stroke-atlas-surface-muted"
              stroke-width="3"
            />
            <circle
              v-for="seg in segments"
              :key="seg.label"
              cx="18"
              cy="18"
              r="15.915"
              fill="none"
              :stroke="seg.color"
              stroke-width="3"
              stroke-linecap="round"
              :stroke-dasharray="`${seg.percentage} ${100 - seg.percentage}`"
              :stroke-dashoffset="25 - seg.offset"
            />
          </svg>
          <div class="absolute inset-0 flex flex-col items-center justify-center">
            <span class="text-2xl font-semibold text-atlas-text-primary">{{ total }}</span>
            <span class="text-xs text-atlas-text-muted">total</span>
          </div>
        </div>

        <!-- Legend -->
        <div
          class="space-y-2"
          role="list"
          aria-label="Sentiment breakdown"
        >
          <div
            v-for="seg in segments"
            :key="seg.label"
            class="flex items-center gap-2 text-sm"
            role="listitem"
          >
            <span
              class="inline-block size-3 rounded-full shrink-0"
              :class="sentimentBgClasses[seg.label] ?? 'bg-atlas-chart-6'"
              aria-hidden="true"
            />
            <span class="capitalize text-atlas-text-primary">{{ seg.label }}</span>
            <span class="text-atlas-text-muted ml-auto tabular-nums">
              {{ seg.count }}
              <span class="text-xs">({{ Math.round(seg.percentage) }}%)</span>
            </span>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
