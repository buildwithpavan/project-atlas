<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { themesApi } from '@/api'
import type { Theme, ThemeSeverity } from '@/api/types'
import { AButton } from '@/components/ui'

const router = useRouter()
const themes = ref<Theme[]>([])
const loading = ref(true)
const error = ref<string | null>(null)
const detecting = ref(false)
const detectError = ref<string | null>(null)
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
  } catch {
    error.value = 'Failed to load themes. Please try again.'
  } finally {
    loading.value = false
  }
}

async function runDetection() {
  detecting.value = true
  detectError.value = null
  try {
    await themesApi.detect()
    // Refresh after a short delay for the job to start
    setTimeout(fetchThemes, 2000)
  } catch {
    detectError.value = 'Failed to start theme detection. Please try again.'
  } finally {
    detecting.value = false
  }
}

function viewTheme(id: string) {
  router.push({ name: 'theme-detail', params: { id } })
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
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
      <div>
        <h1 class="text-2xl font-bold text-voceive-text-primary">Themes</h1>
        <p class="mt-1 text-sm text-voceive-text-secondary">
          Recurring patterns and issues detected across customer conversations
        </p>
      </div>
      <AButton
        :loading="detecting"
        :disabled="detecting"
        @click="runDetection"
      >
        {{ detecting ? 'Detecting…' : 'Detect Themes' }}
      </AButton>
    </div>

    <!-- Detection error -->
    <div
      v-if="detectError"
      role="alert"
      class="rounded-voceive-lg bg-voceive-error-subtle border border-voceive-error/20 p-4 flex items-center justify-between gap-3"
    >
      <p class="text-sm text-voceive-error">{{ detectError }}</p>
      <AButton variant="secondary" size="sm" @click="runDetection">
        Retry
      </AButton>
    </div>

    <!-- Filters -->
    <div class="flex gap-3">
      <div>
        <label for="theme-status-filter" class="sr-only">Filter by status</label>
        <select
          id="theme-status-filter"
          v-model="filterStatus"
          aria-label="Filter by status"
          class="voceive-focus-ring rounded-voceive border border-voceive-border bg-voceive-surface px-3 py-1.5 text-sm text-voceive-text-primary"
          @change="fetchThemes"
        >
          <option value="">All statuses</option>
          <option value="active">Active</option>
          <option value="resolved">Resolved</option>
          <option value="archived">Archived</option>
        </select>
      </div>
      <div>
        <label for="theme-severity-filter" class="sr-only">Filter by severity</label>
        <select
          id="theme-severity-filter"
          v-model="filterSeverity"
          aria-label="Filter by severity"
          class="voceive-focus-ring rounded-voceive border border-voceive-border bg-voceive-surface px-3 py-1.5 text-sm text-voceive-text-primary"
          @change="fetchThemes"
        >
          <option value="">All severities</option>
          <option value="critical">Critical</option>
          <option value="high">High</option>
          <option value="medium">Medium</option>
          <option value="low">Low</option>
        </select>
      </div>
    </div>

    <!-- Loading skeleton -->
    <div v-if="loading" class="space-y-3">
      <div
        v-for="i in 3"
        :key="i"
        class="rounded-voceive-lg bg-voceive-surface border border-voceive-border p-5"
      >
        <div class="flex items-start justify-between gap-4">
          <div class="flex-1">
            <div class="flex items-center gap-2 mb-2">
              <div class="h-5 w-16 animate-pulse rounded-full bg-voceive-surface-muted" />
              <div class="h-4 w-20 animate-pulse rounded bg-voceive-surface-muted" />
            </div>
            <div class="h-5 w-48 animate-pulse rounded bg-voceive-surface-muted" />
            <div class="mt-2 h-4 w-full animate-pulse rounded bg-voceive-surface-muted" />
          </div>
          <div class="shrink-0 space-y-1">
            <div class="h-3 w-24 animate-pulse rounded bg-voceive-surface-muted" />
            <div class="h-3 w-24 animate-pulse rounded bg-voceive-surface-muted" />
          </div>
        </div>
      </div>
    </div>

    <!-- Error state -->
    <div
      v-else-if="error"
      role="alert"
      class="flex flex-col items-center justify-center py-16 text-center"
    >
      <div class="size-16 rounded-full bg-voceive-error-subtle flex items-center justify-center mb-4">
        <svg
          class="size-8 text-voceive-error"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="1.5"
          aria-hidden="true"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z"
          />
        </svg>
      </div>
      <h2 class="text-lg font-semibold text-voceive-text-primary">
        Unable to load themes
      </h2>
      <p class="mt-2 max-w-sm text-sm text-voceive-text-muted">
        {{ error }}
      </p>
      <AButton variant="secondary" size="md" class="mt-4" @click="fetchThemes">
        Try again
      </AButton>
    </div>

    <!-- Empty state -->
    <div v-else-if="sortedThemes.length === 0" class="flex flex-col items-center justify-center py-16 text-center">
      <div class="size-16 rounded-full bg-voceive-brand-subtle flex items-center justify-center mb-4">
        <svg
          class="size-8 text-voceive-brand"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="1.5"
          aria-hidden="true"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.455 2.456L21.75 6l-1.036.259a3.375 3.375 0 00-2.455 2.456z"
          />
        </svg>
      </div>
      <h2 class="text-lg font-semibold text-voceive-text-primary">No themes detected</h2>
      <p class="mt-2 max-w-sm text-sm text-voceive-text-muted">
        Import customer tickets and run theme detection to discover recurring patterns and issues.
      </p>
      <AButton class="mt-5" :loading="detecting" @click="runDetection">
        Detect Themes
      </AButton>
    </div>

    <!-- Themes list -->
    <div v-else class="space-y-3">
      <div
        v-for="theme in sortedThemes"
        :key="theme.id"
        role="link"
        tabindex="0"
        class="rounded-voceive-lg bg-voceive-surface border border-voceive-border p-5 hover:shadow-voceive-sm transition-shadow cursor-pointer"
        @click="viewTheme(theme.id)"
        @keydown.enter="viewTheme(theme.id)"
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
