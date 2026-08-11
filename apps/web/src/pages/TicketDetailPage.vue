<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import * as ticketsApi from '@/api/tickets'
import type { TicketDetail } from '@/api/types'
import { ApiError } from '@/api/errors'
import { AButton, ABadge } from '@/components/ui'
import TicketStatusBadge from '@/components/tickets/TicketStatusBadge.vue'
import TicketPriorityBadge from '@/components/tickets/TicketPriorityBadge.vue'

const route = useRoute()
const router = useRouter()

const ticket = ref<TicketDetail | null>(null)
const loading = ref(true)
const error = ref<string | null>(null)
const notFound = ref(false)

const ticketId = computed(() => route.params.id as string)

function formatDate(iso: string): string {
  try {
    return new Date(iso).toLocaleDateString(undefined, {
      weekday: 'short',
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    })
  } catch {
    return iso
  }
}

function formatConfidence(value: number | null): string {
  if (value === null) return '—'
  return `${Math.round(value * 100)}%`
}

async function fetchTicket() {
  loading.value = true
  error.value = null
  notFound.value = false
  try {
    const res = await ticketsApi.getById(ticketId.value)
    ticket.value = res.data
  } catch (err) {
    if (err instanceof ApiError && err.status === 404) {
      notFound.value = true
    } else if (err instanceof ApiError) {
      error.value = err.detail
    } else {
      error.value = 'Unable to load this ticket.'
    }
  } finally {
    loading.value = false
  }
}

function goBack() {
  router.push({ name: 'tickets' })
}

onMounted(fetchTicket)
</script>

<template>
  <div>
    <!-- Back link -->
    <button
      type="button"
      class="atlas-focus-ring inline-flex items-center gap-1 text-sm text-atlas-text-secondary hover:text-atlas-text-primary transition-colors rounded"
      @click="goBack"
    >
      <svg
        class="size-4"
        viewBox="0 0 20 20"
        fill="currentColor"
        aria-hidden="true"
      >
        <path
          fill-rule="evenodd"
          d="M17 10a.75.75 0 01-.75.75H5.612l4.158 3.96a.75.75 0 11-1.04 1.08l-5.5-5.25a.75.75 0 010-1.08l5.5-5.25a.75.75 0 111.04 1.08L5.612 9.25H16.25A.75.75 0 0117 10z"
          clip-rule="evenodd"
        />
      </svg>
      Back to Tickets
    </button>

    <!-- Loading skeleton -->
    <div
      v-if="loading"
      class="mt-6 space-y-6"
    >
      <div>
        <div class="h-7 w-2/3 animate-pulse rounded bg-atlas-surface-muted" />
        <div class="mt-2 h-4 w-1/3 animate-pulse rounded bg-atlas-surface-muted" />
        <div class="mt-3 flex gap-2">
          <div class="h-5 w-14 animate-pulse rounded-atlas-full bg-atlas-surface-muted" />
          <div class="h-5 w-16 animate-pulse rounded-atlas-full bg-atlas-surface-muted" />
          <div class="h-5 w-20 animate-pulse rounded-atlas-full bg-atlas-surface-muted" />
        </div>
      </div>
      <div class="bg-atlas-surface border border-atlas-border rounded-atlas-lg p-5">
        <div class="h-4 w-24 animate-pulse rounded bg-atlas-surface-muted" />
        <div class="mt-3 space-y-2">
          <div class="h-3 w-full animate-pulse rounded bg-atlas-surface-muted" />
          <div class="h-3 w-5/6 animate-pulse rounded bg-atlas-surface-muted" />
          <div class="h-3 w-3/4 animate-pulse rounded bg-atlas-surface-muted" />
        </div>
      </div>
      <div class="bg-atlas-surface border border-atlas-border rounded-atlas-lg p-5">
        <div class="h-4 w-32 animate-pulse rounded bg-atlas-surface-muted" />
        <div class="mt-4 space-y-3">
          <div class="h-3 w-full animate-pulse rounded bg-atlas-surface-muted" />
          <div class="h-3 w-2/3 animate-pulse rounded bg-atlas-surface-muted" />
        </div>
      </div>
    </div>

    <!-- Not found -->
    <div
      v-else-if="notFound"
      class="mt-6 flex flex-col items-center justify-center py-16 text-center"
    >
      <h2 class="text-lg font-semibold text-atlas-text-primary">
        Ticket not found
      </h2>
      <p class="mt-2 text-sm text-atlas-text-muted">
        This ticket may have been removed or doesn't exist.
      </p>
      <AButton
        variant="secondary"
        size="md"
        class="mt-4"
        @click="goBack"
      >
        Back to Tickets
      </AButton>
    </div>

    <!-- Error -->
    <div
      v-else-if="error"
      role="alert"
      class="mt-6 flex flex-col items-center justify-center py-16 text-center"
    >
      <h2 class="text-lg font-semibold text-atlas-text-primary">
        Unable to load ticket
      </h2>
      <p class="mt-2 max-w-sm text-sm text-atlas-text-muted">
        {{ error }}
      </p>
      <div class="mt-4 flex gap-3">
        <AButton
          variant="secondary"
          size="md"
          @click="goBack"
        >
          Back to Tickets
        </AButton>
        <AButton
          variant="secondary"
          size="md"
          @click="fetchTicket"
        >
          Try again
        </AButton>
      </div>
    </div>

    <!-- Ticket detail -->
    <template v-else-if="ticket">
      <!-- Header -->
      <div class="mt-6">
        <h1 class="text-xl font-semibold text-atlas-text-primary">
          {{ ticket.subject }}
        </h1>
        <div class="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1 text-sm text-atlas-text-secondary">
          <span v-if="ticket.customer_name || ticket.customer_email">
            {{ ticket.customer_name || ticket.customer_email }}
            <span
              v-if="ticket.customer_name && ticket.customer_email"
              class="text-atlas-text-muted"
            >
              ({{ ticket.customer_email }})
            </span>
          </span>
          <span
            v-else
            class="text-atlas-text-muted"
          >Unknown customer</span>
          <span class="text-atlas-text-muted">
            {{ formatDate(ticket.created_at) }}
          </span>
        </div>
        <div class="mt-3 flex flex-wrap items-center gap-2">
          <TicketStatusBadge :status="ticket.status" />
          <TicketPriorityBadge :priority="ticket.priority" />
          <ABadge
            v-if="ticket.category"
            variant="default"
          >
            {{ ticket.category }}
          </ABadge>
        </div>
      </div>

      <!-- Customer message -->
      <div class="mt-6 bg-atlas-surface border border-atlas-border rounded-atlas-lg p-5">
        <h2 class="text-sm font-medium text-atlas-text-secondary">
          Customer Message
        </h2>
        <p
          v-if="ticket.description"
          class="mt-3 text-sm text-atlas-text-primary whitespace-pre-wrap leading-relaxed"
        >
          {{ ticket.description }}
        </p>
        <p
          v-else
          class="mt-3 text-sm text-atlas-text-muted italic"
        >
          No message content available.
        </p>
      </div>

      <!-- AI Analysis -->
      <div class="mt-6 bg-atlas-surface border border-atlas-border rounded-atlas-lg p-5">
        <h2 class="text-sm font-medium text-atlas-text-secondary">
          Atlas Analysis
        </h2>

        <!-- No analysis at all -->
        <template v-if="!ticket.ai_analysis">
          <p class="mt-3 text-sm text-atlas-text-muted">
            This ticket has not been analyzed yet.
          </p>
        </template>

        <!-- Pending -->
        <template v-else-if="ticket.ai_analysis.status === 'pending'">
          <div class="mt-3 flex items-center gap-2 text-sm text-atlas-text-muted">
            <div class="size-2 rounded-full bg-atlas-warning animate-pulse" />
            Atlas is waiting to analyze this ticket.
          </div>
        </template>

        <!-- Processing -->
        <template v-else-if="ticket.ai_analysis.status === 'processing'">
          <div class="mt-3 flex items-center gap-2 text-sm text-atlas-text-muted">
            <svg
              class="size-4 animate-spin text-atlas-brand"
              viewBox="0 0 24 24"
              fill="none"
              aria-hidden="true"
            >
              <circle
                class="opacity-25"
                cx="12"
                cy="12"
                r="10"
                stroke="currentColor"
                stroke-width="4"
              />
              <path
                class="opacity-75"
                fill="currentColor"
                d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
              />
            </svg>
            Atlas is analyzing this ticket…
          </div>
        </template>

        <!-- Failed -->
        <template v-else-if="ticket.ai_analysis.status === 'failed'">
          <p class="mt-3 text-sm text-atlas-text-muted">
            Analysis couldn't be completed for this ticket. It may be retried automatically.
          </p>
        </template>

        <!-- Completed -->
        <template v-else-if="ticket.ai_analysis.status === 'completed'">
          <!-- Summary -->
          <p
            v-if="ticket.ai_analysis.summary"
            class="mt-3 text-sm text-atlas-text-primary leading-relaxed"
          >
            "{{ ticket.ai_analysis.summary }}"
          </p>

          <!-- Metrics grid -->
          <div class="mt-4 grid grid-cols-1 sm:grid-cols-3 gap-4">
            <!-- Sentiment -->
            <div>
              <p class="text-xs font-medium text-atlas-text-muted uppercase tracking-wider">
                Sentiment
              </p>
              <p class="mt-1">
                <ABadge
                  :variant="
                    ticket.ai_analysis.sentiment === 'positive' ? 'success'
                    : ticket.ai_analysis.sentiment === 'negative' ? 'error'
                      : ticket.ai_analysis.sentiment === 'mixed' ? 'warning'
                        : 'default'
                  "
                >
                  {{ ticket.ai_analysis.sentiment || 'Unknown' }}
                </ABadge>
              </p>
            </div>

            <!-- Confidence -->
            <div>
              <p class="text-xs font-medium text-atlas-text-muted uppercase tracking-wider">
                Confidence
              </p>
              <p class="mt-1 text-sm font-medium text-atlas-text-primary tabular-nums">
                {{ formatConfidence(ticket.ai_analysis.confidence) }}
              </p>
            </div>

            <!-- Category -->
            <div>
              <p class="text-xs font-medium text-atlas-text-muted uppercase tracking-wider">
                Category
              </p>
              <p class="mt-1 text-sm text-atlas-text-primary capitalize">
                {{ ticket.ai_analysis.category || '—' }}
              </p>
            </div>
          </div>

          <!-- Signals -->
          <div class="mt-4 border-t border-atlas-border pt-4">
            <p class="text-xs font-medium text-atlas-text-muted uppercase tracking-wider mb-2">
              Signals
            </p>
            <div class="flex flex-wrap gap-2">
              <ABadge
                v-if="ticket.ai_analysis.feature_request"
                variant="info"
              >
                Feature Request
              </ABadge>
              <ABadge
                v-if="ticket.ai_analysis.bug_report"
                variant="error"
              >
                Bug Report
              </ABadge>
              <ABadge
                v-if="ticket.ai_analysis.knowledge_gap"
                variant="warning"
              >
                Knowledge Gap
              </ABadge>
              <span
                v-if="!ticket.ai_analysis.feature_request && !ticket.ai_analysis.bug_report && !ticket.ai_analysis.knowledge_gap"
                class="text-sm text-atlas-text-muted"
              >
                No specific signals detected.
              </span>
            </div>
          </div>
        </template>
      </div>
    </template>
  </div>
</template>