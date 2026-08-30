<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { themesApi } from '@/api'
import type { Theme, ThemeSeverity } from '@/api/types'

const router = useRouter()
const themes = ref<Theme[]>([])
const loading = ref(true)
const error = ref<string | null>(null)
const detecting = ref(false)
const filterStatus = ref('active')
const filterSeverity = ref('')

const severityColors: Record<ThemeSeverity, string> = {
  critical: 'bg-voceive-error text-white',
  high: 'bg-orange-100 text-orange-800',
  medium: 'bg-voceive-warning-subtle text-yellow-800',
  low: 'bg-voceive-info-subtle text-voceive-info',
}

const severityOrder: Record<ThemeSeverity, number> = {
  critical: 0,
  high: 1,
  medium: 2,
  low: 3,
}

const sortedThemes = computed(() =>
  [...themes.value].sort((a, b) => {
    const sevDiff = severityOrder[a.severity] - severityOrder[b.severity]
    return sevDiff !== 0 ? sevDiff : b.ticket_count - a.ticket_count
  })
)

async function fetchThemes() {
  loading.value = true
  error.value = null
  try {
    const res = await themesApi.list({
      status: filterStatus.value || undefined,
      severity: filterSeverity.value || undefined,
    })
    themes.value = res.data
  } catch (e) {
    error.value = 'Failed to load themes'
  } finally {
    loading.value = false
  }
}

async function runDetection() {
  detecting.value = true
  try {
    await themesApi.detect()
    // Refresh after a short delay for the job to start
    setTimeout(fetchThemes, 2000)
  } catch {
    error.value = 'Failed to start theme detection'
  } finally {
    detecting.value = false
  }
}

function viewTheme(id: string) {
  router.push(`/themes/${id}`)
}

function formatDate(dateStr: string | null) {
  if (!dateStr) return '—'
  return new Date(dateStr).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  })
}

onMounted(fetchThemes)
</script>

<template>
  <div class="space-y-6">
    <!-- Header -->
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-2xl font-bold text-voceive-text-primary">Themes</h1>
        <p class="mt-1 text-sm text-voceive-text-secondary">
          Recurring patterns and issues detected across customer conversations
        </p>
      </div>
      <button
        class="inline-flex items-center gap-2 rounded-voceive px-4 py-2 text-sm font-medium text-white bg-voceive-brand hover:bg-voceive-brand-hover transition-colors disabled:opacity-50"
        :disabled="detecting"
        @click="runDetection"
      >
        <svg v-if="detecting" class="animate-spin size-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
        </svg>
        {{ detecting ? 'Detecting…' : 'Detect Themes' }}
      </button>
    </div>

    <!-- Filters -->
    <div class="flex gap-3">
      <select
        v-model="filterStatus"
        class="rounded-voceive border border-voceive-border bg-voceive-surface px-3 py-1.5 text-sm text-voceive-text-primary"
        @change="fetchThemes"
      >
        <option value="">All statuses</option>
        <option value="active">Active</option>
        <option value="resolved">Resolved</option>
        <option value="archived">Archived</option>
      </select>
      <select
        v-model="filterSeverity"
        class="rounded-voceive border border-voceive-border bg-voceive-surface px-3 py-1.5 text-sm text-voceive-text-primary"
        @change="fetchThemes"
      >
        <option value="">All severities</option>
        <option value="critical">Critical</option>
        <option value="high">High</option>
        <option value="medium">Medium</option>
        <option value="low">Low</option>
      </select>
    </div>

    <!-- Loading state -->
    <div v-if="loading" class="flex items-center justify-center py-12">
      <div class="text-sm text-voceive-text-muted">Loading themes…</div>
    </div>

    <!-- Error state -->
    <div v-else-if="error" class="rounded-voceive-md bg-voceive-error-subtle border border-voceive-error/20 p-4 text-sm text-voceive-error">
      {{ error }}
    </div>

    <!-- Empty state -->
    <div v-else-if="sortedThemes.length === 0" class="rounded-voceive-lg bg-voceive-surface border border-voceive-border p-12 text-center">
      <div class="mx-auto max-w-sm">
        <h3 class="text-lg font-semibold text-voceive-text-primary">No themes detected</h3>
        <p class="mt-2 text-sm text-voceive-text-secondary">
          Upload customer conversations and run theme detection to discover recurring patterns and issues.
        </p>
      </div>
    </div>

    <!-- Themes list -->
    <div v-else class="space-y-3">
      <div
        v-for="theme in sortedThemes"
        :key="theme.id"
        class="rounded-voceive-lg bg-voceive-surface border border-voceive-border p-5 hover:shadow-voceive-sm transition-shadow cursor-pointer"
        @click="viewTheme(theme.id)"
      >
        <div class="flex items-start justify-between gap-4">
          <div class="min-w-0 flex-1">
            <div class="flex items-center gap-2 mb-1">
              <span
                class="inline-flex items-center rounded-voceive-full px-2 py-0.5 text-xs font-medium"
                :class="severityColors[theme.severity]"
              >
                {{ theme.severity }}
              </span>
              <span class="text-xs text-voceive-text-muted">
                {{ theme.ticket_count }} ticket{{ theme.ticket_count === 1 ? '' : 's' }}
              </span>
            </div>
            <h3 class="text-base font-semibold text-voceive-text-primary">{{ theme.title }}</h3>
            <p class="mt-1 text-sm text-voceive-text-secondary line-clamp-2">{{ theme.description }}</p>
          </div>
          <div class="shrink-0 text-right text-xs text-voceive-text-muted">
            <div>First: {{ formatDate(theme.first_seen_at) }}</div>
            <div>Last: {{ formatDate(theme.last_seen_at) }}</div>
          </div>
        </div>

        <div v-if="theme.recommended_action" class="mt-3 rounded-voceive bg-voceive-brand-subtle px-3 py-2 text-sm text-voceive-brand">
          <span class="font-medium">Recommendation:</span> {{ theme.recommended_action }}
        </div>
      </div>
    </div>
  </div>
</template>
