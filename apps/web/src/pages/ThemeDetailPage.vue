<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { themesApi } from '@/api'
import type { ThemeDetail, ThemeSeverity } from '@/api/types'

const route = useRoute()
const router = useRouter()
const theme = ref<ThemeDetail | null>(null)
const loading = ref(true)
const error = ref<string | null>(null)

const severityColors: Record<ThemeSeverity, string> = {
  critical: 'bg-voceive-error text-white',
  high: 'bg-orange-100 text-orange-800',
  medium: 'bg-voceive-warning-subtle text-yellow-800',
  low: 'bg-voceive-info-subtle text-voceive-info',
}

async function fetchTheme() {
  loading.value = true
  error.value = null
  try {
    const res = await themesApi.getById(route.params.id as string)
    theme.value = res.data
  } catch {
    error.value = 'Failed to load theme'
  } finally {
    loading.value = false
  }
}

function formatDate(dateStr: string | null) {
  if (!dateStr) return '—'
  return new Date(dateStr).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  })
}

function viewTicket(id: string) {
  router.push(`/tickets/${id}`)
}

onMounted(fetchTheme)
</script>

<template>
  <div class="space-y-6">
    <!-- Back link -->
    <button
      class="inline-flex items-center gap-1 text-sm text-voceive-text-secondary hover:text-voceive-text-primary transition-colors"
      @click="router.push('/themes')"
    >
      ← Back to Themes
    </button>

    <!-- Loading -->
    <div v-if="loading" class="flex items-center justify-center py-12">
      <div class="text-sm text-voceive-text-muted">Loading theme…</div>
    </div>

    <!-- Error -->
    <div v-else-if="error" class="rounded-voceive-md bg-voceive-error-subtle border border-voceive-error/20 p-4 text-sm text-voceive-error">
      {{ error }}
    </div>

    <template v-else-if="theme">
      <!-- Header -->
      <div class="rounded-voceive-lg bg-voceive-surface border border-voceive-border p-6">
        <div class="flex items-start justify-between gap-4">
          <div>
            <div class="flex items-center gap-2 mb-2">
              <span
                class="inline-flex items-center rounded-voceive-full px-2.5 py-0.5 text-xs font-medium"
                :class="severityColors[theme.severity]"
              >
                {{ theme.severity }}
              </span>
              <span class="inline-flex items-center rounded-voceive-full px-2.5 py-0.5 text-xs font-medium bg-voceive-surface-muted text-voceive-text-secondary">
                {{ theme.status }}
              </span>
            </div>
            <h1 class="text-2xl font-bold text-voceive-text-primary">{{ theme.title }}</h1>
            <p class="mt-2 text-sm text-voceive-text-secondary">{{ theme.description }}</p>
          </div>
          <div class="shrink-0 text-right text-sm text-voceive-text-muted">
            <div>{{ theme.ticket_count }} ticket{{ theme.ticket_count === 1 ? '' : 's' }}</div>
            <div class="mt-1">First seen: {{ formatDate(theme.first_seen_at) }}</div>
            <div>Last seen: {{ formatDate(theme.last_seen_at) }}</div>
          </div>
        </div>

        <!-- Evidence & Recommendation -->
        <div class="mt-4 grid gap-4 sm:grid-cols-2">
          <div v-if="theme.evidence_summary" class="rounded-voceive bg-voceive-surface-muted p-4">
            <h3 class="text-sm font-semibold text-voceive-text-primary mb-1">Evidence Summary</h3>
            <p class="text-sm text-voceive-text-secondary">{{ theme.evidence_summary }}</p>
          </div>
          <div v-if="theme.recommended_action" class="rounded-voceive bg-voceive-brand-subtle p-4">
            <h3 class="text-sm font-semibold text-voceive-brand mb-1">Recommended Action</h3>
            <p class="text-sm text-voceive-text-secondary">{{ theme.recommended_action }}</p>
          </div>
        </div>
      </div>

      <!-- Supporting Tickets -->
      <div>
        <h2 class="text-lg font-semibold text-voceive-text-primary mb-3">Supporting Tickets</h2>
        <div class="space-y-2">
          <div
            v-for="ticket in theme.tickets"
            :key="ticket.id"
            class="rounded-voceive bg-voceive-surface border border-voceive-border p-4 hover:shadow-voceive-sm transition-shadow cursor-pointer"
            @click="viewTicket(ticket.id)"
          >
            <div class="flex items-start justify-between gap-4">
              <div class="min-w-0 flex-1">
                <h4 class="text-sm font-medium text-voceive-text-primary">{{ ticket.subject }}</h4>
                <p v-if="ticket.evidence_text" class="mt-1 text-xs text-voceive-text-secondary line-clamp-2">
                  {{ ticket.evidence_text }}
                </p>
              </div>
              <div class="shrink-0 text-right">
                <div v-if="ticket.relevance_score" class="text-xs text-voceive-text-muted">
                  {{ (ticket.relevance_score * 100).toFixed(0) }}% relevant
                </div>
                <div class="text-xs text-voceive-text-muted mt-1">{{ formatDate(ticket.created_at) }}</div>
              </div>
            </div>
            <div class="mt-2 flex gap-2">
              <span v-if="ticket.priority" class="text-xs text-voceive-text-muted">{{ ticket.priority }}</span>
              <span v-if="ticket.customer_name" class="text-xs text-voceive-text-muted">{{ ticket.customer_name }}</span>
            </div>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
