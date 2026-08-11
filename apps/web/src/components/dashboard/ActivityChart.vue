<script setup lang="ts">
import { computed } from 'vue'

const props = defineProps<{
  timeline: Record<string, number>
  loading?: boolean
}>()

interface DataPoint {
  label: string
  value: number
  height: number
}

const points = computed<DataPoint[]>(() => {
  const entries = Object.entries(props.timeline)
  if (entries.length === 0) return []

  // Sort chronologically
  entries.sort(([a], [b]) => a.localeCompare(b))

  const max = Math.max(...entries.map(([, v]) => v), 1)
  return entries.map(([label, value]) => ({
    label,
    value,
    height: (value / max) * 100,
  }))
})

const isEmpty = computed(() => points.value.length === 0)

function formatDate(dateStr: string): string {
  try {
    const date = new Date(dateStr)
    return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
  } catch {
    return dateStr
  }
}
</script>

<template>
  <div class="bg-atlas-surface border border-atlas-border rounded-atlas-lg shadow-atlas-sm p-5">
    <h3 class="text-sm font-medium text-atlas-text-secondary">
      Ticket Activity
    </h3>

    <!-- Loading -->
    <template v-if="loading">
      <div class="mt-4 flex items-end gap-1 h-32">
        <div
          v-for="i in 12"
          :key="i"
          class="flex-1 animate-pulse rounded-t bg-atlas-surface-muted"
          :style="{ height: `${30 + Math.random() * 60}%` }"
        />
      </div>
    </template>

    <!-- Empty -->
    <template v-else-if="isEmpty">
      <p class="mt-4 text-sm text-atlas-text-muted">
        No timeline data available yet. Activity data will appear as tickets are processed.
      </p>
    </template>

    <!-- Bar chart -->
    <template v-else>
      <div
        class="mt-4"
        role="img"
        :aria-label="`Ticket activity over time: ${points.map(p => `${p.label}: ${p.value}`).join(', ')}`"
      >
        <div class="flex items-end gap-1 h-32">
          <div
            v-for="point in points"
            :key="point.label"
            class="flex-1 min-w-1 rounded-t bg-atlas-brand/80 hover:bg-atlas-brand transition-colors group relative"
            :style="{ height: `${Math.max(point.height, 2)}%` }"
          >
            <!-- Tooltip -->
            <div class="absolute bottom-full left-1/2 -translate-x-1/2 mb-1 hidden group-hover:block z-10">
              <div class="bg-atlas-text-primary text-white text-xs rounded px-2 py-1 whitespace-nowrap shadow-atlas-md">
                {{ point.value }} tickets
              </div>
            </div>
          </div>
        </div>
        <!-- X-axis labels — show first, middle, last to avoid clutter -->
        <div
          v-if="points.length > 0"
          class="flex justify-between mt-2 text-xs text-atlas-text-muted"
        >
          <span>{{ formatDate(points[0].label) }}</span>
          <span v-if="points.length > 2">{{ formatDate(points[Math.floor(points.length / 2)].label) }}</span>
          <span v-if="points.length > 1">{{ formatDate(points[points.length - 1].label) }}</span>
        </div>
      </div>
    </template>
  </div>
</template>
