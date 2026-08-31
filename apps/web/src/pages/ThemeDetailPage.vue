<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { themesApi } from '@/api'
import type { ThemeDetail, ThemeSeverity } from '@/api/types'
import { AButton } from '@/components/ui'

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
    error.value = 'Failed to load theme. Please try again.'
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
  router.push({ name: 'ticket-detail', params: { id } })
}

onMounted(fetchTheme)
</script>

<template>
  <div class="space-y-6">
    <!-- Back link -->
    <AButton
      variant="ghost"
      size="sm"
      @click="router.push({ name: 'themes' })"
    >
      ← Back to Themes
    </AButton>

    <!-- Loading skeleton -->
    <template v-if="loading">
      <div class="rounded-voceive-lg bg-voceive-surface border border-voceive-border p-6">
        <div class="flex items-start justify-between gap-4">
          <div class="flex-1">
            <div class="flex items-center gap-2 mb-3">
              <div class="h-5 w-16 animate-pulse rounded-full bg-voceive-surface-muted" />
              <div class="h-5 w-20 animate-pulse rounded-full bg-voceive-surface-muted" />
            </div>
            <div class="h-7 w-64 animate-pulse rounded bg-voceive-surface-muted" />
            <div class="mt-2 h-4 w-full animate-pulse rounded bg-voceive-surface-muted" />
            <div class="mt-1 h-4 w-3/4 animate-pulse rounded bg-voceive-surface-muted" />
          </div>
          <div class="shrink-0 space-y-2">
            <div class="h-4 w-20 animate-pulse rounded bg-voceive-surface-muted" />
            <div class="h-3 w-28 animate-pulse rounded bg-voceive-surface-muted" />
            <div class="h-3 w-28 animate-pulse rounded bg-voceive-surface-muted" />
          </div>
        </div>
        <div class="mt-4 grid gap-4 sm:grid-cols-2">
          <div class="rounded-voceive bg-voceive-surface-muted p-4">
            <div class="h-4 w-28 animate-pulse rounded bg-voceive-surface-muted" />
            <div class="mt-2 h-4 w-full animate-pulse rounded bg-voceive-surface-muted" />
          </div>
          <div class="rounded-voceive bg-voceive-surface-muted p-4">
            <div class="h-4 w-32 animate-pulse rounded bg-voceive-surface-muted" />
            <div class="mt-2 h-4 w-full animate-pulse rounded bg-voceive-surface-muted" />
          </div>
        </div>
      </div>

      <div>
        <div class="h-5 w-36 animate-pulse rounded bg-voceive-surface-muted mb-3" />
        <div class="space-y-2">
          <div
            v-for="i in 2"
            :key="i"
            class="rounded-voceive bg-voceive-surface border border-voceive-border p-4"
          >
            <div class="h-4 w-48 animate-pulse rounded bg-voceive-surface-muted" />
            <div class="mt-2 h-3 w-full animate-pulse rounded bg-voceive-surface-muted" />
          </div>
        </div>
      </div>
    </template>

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
        Unable to load theme
      </h2>
      <p class="mt-2 max-w-sm text-sm text-voceive-text-muted">
        {{ error }}
      </p>
      <AButton
        variant="secondary"
        size="md"
        class="mt-4"
        @click="fetchTheme"
      >
        Try again
      </AButton>
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
            <h1 class="text-2xl font-bold text-voceive-text-primary">
              {{ theme.title }}
            </h1>
            <p class="mt-2 text-sm text-voceive-text-secondary">
              {{ theme.description }}
            </p>
          </div>
          <div class="shrink-0 text-right text-sm text-voceive-text-muted">
            <div>
              {{ theme.ticket_count }} ticket{{ theme.ticket_count === 1 ? '' : 's' }}
            </div>
            <div class="mt-1">
              First seen: {{ formatDate(theme.first_seen_at) }}
            </div>
            <div>
              Last seen: {{ formatDate(theme.last_seen_at) }}
            </div>
          </div>
        </div>

        <!-- Evidence & Recommendation -->
        <div class="mt-4 grid gap-4 sm:grid-cols-2">
          <div
            v-if="theme.evidence_summary"
            class="rounded-voceive bg-voceive-surface-muted p-4"
          >
            <h3 class="text-sm font-semibold text-voceive-text-primary mb-1">
              Evidence Summary
            </h3>
            <p class="text-sm text-voceive-text-secondary">
              {{ theme.evidence_summary }}
            </p>
          </div>
          <div
            v-if="theme.recommended_action"
            class="rounded-voceive bg-voceive-brand-subtle p-4"
          >
            <h3 class="text-sm font-semibold text-voceive-brand mb-1">
              Recommended Action
            </h3>
            <p class="text-sm text-voceive-text-secondary">
              {{ theme.recommended_action }}
            </p>
          </div>
        </div>
      </div>

      <!-- Supporting Tickets -->
      <div>
        <h2 class="text-lg font-semibold text-voceive-text-primary mb-3">
          Supporting Tickets
        </h2>

        <div
          v-if="theme.tickets.length === 0"
          class="rounded-voceive bg-voceive-surface border border-voceive-border p-8 text-center"
        >
          <p class="text-sm text-voceive-text-muted">
            No supporting tickets found for this theme.
          </p>
        </div>

        <div
          v-else
          class="space-y-2"
        >
          <div
            v-for="ticket in theme.tickets"
            :key="ticket.id"
            role="link"
            tabindex="0"
            class="rounded-voceive bg-voceive-surface border border-voceive-border p-4 hover:shadow-voceive-sm transition-shadow cursor-pointer"
            @click="viewTicket(ticket.id)"
            @keydown.enter="viewTicket(ticket.id)"
          >
            <div class="flex items-start justify-between gap-4">
              <div class="min-w-0 flex-1">
                <h4 class="text-sm font-medium text-voceive-text-primary">
                  {{ ticket.subject }}
                </h4>
                <p
                  v-if="ticket.evidence_text"
                  class="mt-1 text-xs text-voceive-text-secondary line-clamp-2"
                >
                  {{ ticket.evidence_text }}
                </p>
              </div>
              <div class="shrink-0 text-right">
                <div
                  v-if="ticket.relevance_score"
                  class="text-xs text-voceive-text-muted"
                >
                  {{ (ticket.relevance_score * 100).toFixed(0) }}% relevant
                </div>
                <div class="text-xs text-voceive-text-muted mt-1">
                  {{ formatDate(ticket.created_at) }}
                </div>
              </div>
            </div>
            <div class="mt-2 flex gap-2">
              <span
                v-if="ticket.priority"
                class="text-xs text-voceive-text-muted"
              >
                {{ ticket.priority }}
              </span>
              <span
                v-if="ticket.customer_name"
                class="text-xs text-voceive-text-muted"
              >
                {{ ticket.customer_name }}
              </span>
            </div>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
