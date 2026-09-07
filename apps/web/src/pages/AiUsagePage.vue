<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import * as aiApi from '@/api/ai'
import type { AiQuota, AiUsage } from '@/api/types'
import { ApiError } from '@/api/errors'
import { ACard } from '@/components/ui'
import AiUsageSkeleton from '@/components/ai-usage/AiUsageSkeleton.vue'
import AiUsageError from '@/components/ai-usage/AiUsageError.vue'
import AiUsageEmptyState from '@/components/ai-usage/AiUsageEmptyState.vue'

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

const loading = ref(true)
const error = ref<string | null>(null)
const quota = ref<AiQuota | null>(null)
const usage = ref<AiUsage | null>(null)

// ---------------------------------------------------------------------------
// Computed
// ---------------------------------------------------------------------------

const isEmpty = computed(() =>
  usage.value !== null && usage.value.request_count === 0,
)

const tokenPercentage = computed(() => {
  if (!quota.value) return null
  return quota.value.current_month.token_percentage_used
})

const costPercentage = computed(() => {
  if (!quota.value) return null
  return quota.value.current_month.cost_percentage_used
})

const quotaStatus = computed<'normal' | 'warning' | 'critical' | 'exhausted'>(() => {
  const tp = tokenPercentage.value
  const cp = costPercentage.value
  const pct = Math.max(tp ?? 0, cp ?? 0)
  if (pct >= 100) return 'exhausted'
  if (pct >= 90) return 'critical'
  if (pct >= 75) return 'warning'
  return 'normal'
})

const hasTokenLimit = computed(() =>
  quota.value !== null && quota.value.ai_monthly_token_limit !== null,
)

const hasCostLimit = computed(() =>
  quota.value !== null && quota.value.ai_monthly_cost_limit !== null,
)

const hasAnyLimit = computed(() => hasTokenLimit.value || hasCostLimit.value)

const periodLabel = computed(() => {
  if (!usage.value) return ''
  const period = usage.value.period
  // YYYY-MM format → "August 2026"
  const match = period.match(/^(\d{4})-(\d{2})$/)
  if (match) {
    const date = new Date(Number(match[1]), Number(match[2]) - 1)
    return date.toLocaleDateString('en-US', { month: 'long', year: 'numeric' })
  }
  return period
})

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function formatNumber(n: number): string {
  return n.toLocaleString('en-US')
}

function formatCost(n: number): string {
  return `$${n.toFixed(2)}`
}

function formatPercentage(n: number | null): string {
  if (n === null) return '—'
  return `${n.toFixed(1)}%`
}

function progressBarColor(pct: number | null): string {
  if (pct === null) return 'bg-voceive-ai'
  if (pct >= 100) return 'bg-voceive-error'
  if (pct >= 90) return 'bg-voceive-error'
  if (pct >= 75) return 'bg-voceive-warning'
  return 'bg-voceive-ai'
}

function progressBarWidth(pct: number | null): string {
  if (pct === null) return '0%'
  return `${Math.min(pct, 100)}%`
}

// ---------------------------------------------------------------------------
// Data loading
// ---------------------------------------------------------------------------

async function fetchData() {
  loading.value = true
  error.value = null
  try {
    const [quotaRes, usageRes] = await Promise.all([
      aiApi.getQuota(),
      aiApi.getUsage(),
    ])
    quota.value = quotaRes.data
    usage.value = usageRes.data
  } catch (err) {
    if (err instanceof ApiError) {
      error.value = err.detail
    } else {
      error.value = 'Something went wrong while loading AI usage data.'
    }
  } finally {
    loading.value = false
  }
}

onMounted(fetchData)
</script>

<template>
  <div>
    <!-- Loading skeleton -->
    <AiUsageSkeleton v-if="loading" />

    <!-- Error state -->
    <AiUsageError
      v-else-if="error"
      :message="error"
      @retry="fetchData"
    />

    <!-- Empty state -->
    <AiUsageEmptyState v-else-if="isEmpty" />

    <!-- Content -->
    <template v-else-if="quota && usage">
      <!-- Header -->
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2">
        <div>
          <h1 class="text-xl font-semibold text-voceive-text-primary">
            Organization AI Usage
          </h1>
          <p class="mt-1 text-sm text-voceive-text-muted">
            {{ periodLabel }}
          </p>
        </div>
      </div>

      <!-- Quota exhausted banner -->
      <div
        v-if="quotaStatus === 'exhausted'"
        role="alert"
        class="mt-4 rounded-voceive-lg border border-voceive-error bg-voceive-error-subtle p-4"
      >
        <div class="flex items-start gap-3">
          <svg
            class="size-5 text-voceive-error shrink-0 mt-0.5"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="1.5"
            aria-hidden="true"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z"
            />
          </svg>
          <div>
            <p class="text-sm font-medium text-voceive-error">
              AI quota exhausted
            </p>
            <p class="mt-1 text-sm text-voceive-text-secondary">
              Your organization has reached its AI usage limit for this period. AI-powered features such as Ask Voceive may be unavailable until the quota resets.
            </p>
          </div>
        </div>
      </div>

      <!-- Quota warning banner -->
      <div
        v-else-if="quotaStatus === 'critical'"
        role="status"
        class="mt-4 rounded-voceive-lg border border-voceive-warning bg-voceive-warning-subtle p-4"
      >
        <div class="flex items-start gap-3">
          <svg
            class="size-5 text-voceive-warning shrink-0 mt-0.5"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="1.5"
            aria-hidden="true"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z"
            />
          </svg>
          <div>
            <p class="text-sm font-medium text-voceive-warning">
              Approaching AI quota limit
            </p>
            <p class="mt-1 text-sm text-voceive-text-secondary">
              Your organization has used over 90% of its AI quota for this period.
            </p>
          </div>
        </div>
      </div>

      <!-- Quota cards -->
      <div class="mt-6 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <!-- Tokens used -->
        <ACard>
          <p class="text-sm font-medium text-voceive-text-secondary">Tokens Used</p>
          <p class="mt-2 text-3xl font-semibold text-voceive-text-primary tracking-tight">
            {{ formatNumber(usage.tokens.used) }}
          </p>
          <template v-if="hasTokenLimit">
            <div class="mt-3">
              <div
                class="h-2 w-full rounded-full bg-voceive-surface-muted overflow-hidden"
                role="progressbar"
                :aria-valuenow="tokenPercentage ?? 0"
                aria-valuemin="0"
                aria-valuemax="100"
                :aria-label="`Token usage: ${formatPercentage(tokenPercentage)} used`"
              >
                <div
                  class="h-full rounded-full transition-all"
                  :class="progressBarColor(tokenPercentage)"
                  :style="{ width: progressBarWidth(tokenPercentage) }"
                />
              </div>
              <p class="mt-1 text-sm text-voceive-text-muted">
                {{ formatPercentage(tokenPercentage) }} used of {{ formatNumber(quota.ai_monthly_token_limit!) }} limit
              </p>
            </div>
          </template>
          <p v-else class="mt-1 text-sm text-voceive-text-muted">No token limit set</p>
        </ACard>

        <!-- Cost -->
        <ACard>
          <p class="text-sm font-medium text-voceive-text-secondary">Estimated Cost</p>
          <p class="mt-2 text-3xl font-semibold text-voceive-text-primary tracking-tight">
            {{ formatCost(usage.cost.used) }}
          </p>
          <template v-if="hasCostLimit">
            <div class="mt-3">
              <div
                class="h-2 w-full rounded-full bg-voceive-surface-muted overflow-hidden"
                role="progressbar"
                :aria-valuenow="costPercentage ?? 0"
                aria-valuemin="0"
                aria-valuemax="100"
                :aria-label="`Cost usage: ${formatPercentage(costPercentage)} used`"
              >
                <div
                  class="h-full rounded-full transition-all"
                  :class="progressBarColor(costPercentage)"
                  :style="{ width: progressBarWidth(costPercentage) }"
                />
              </div>
              <p class="mt-1 text-sm text-voceive-text-muted">
                {{ formatPercentage(costPercentage) }} used of {{ formatCost(quota.ai_monthly_cost_limit!) }} limit
              </p>
            </div>
          </template>
          <p v-else class="mt-1 text-sm text-voceive-text-muted">No cost limit set</p>
        </ACard>

        <!-- Requests -->
        <ACard>
          <p class="text-sm font-medium text-voceive-text-secondary">AI Requests</p>
          <p class="mt-2 text-3xl font-semibold text-voceive-text-primary tracking-tight">
            {{ formatNumber(usage.request_count) }}
          </p>
          <p class="mt-1 text-sm text-voceive-text-muted">
            {{ usage.average_latency_ms > 0 ? `${usage.average_latency_ms.toFixed(0)}ms avg latency` : 'This period' }}
          </p>
        </ACard>
      </div>

      <!-- Remaining quota summary (only when limits exist) -->
      <div
        v-if="hasAnyLimit"
        class="mt-4 rounded-voceive-lg border border-voceive-border bg-voceive-surface-muted p-4"
      >
        <p class="text-sm font-medium text-voceive-text-secondary">Remaining Quota</p>
        <div class="mt-2 flex flex-wrap gap-6">
          <div v-if="hasTokenLimit">
            <span class="text-lg font-semibold text-voceive-text-primary">
              {{ formatNumber(quota.current_month.tokens_remaining ?? 0) }}
            </span>
            <span class="ml-1 text-sm text-voceive-text-muted">tokens remaining</span>
          </div>
          <div v-if="hasCostLimit">
            <span class="text-lg font-semibold text-voceive-text-primary">
              {{ formatCost(quota.current_month.cost_remaining ?? 0) }}
            </span>
            <span class="ml-1 text-sm text-voceive-text-muted">cost remaining</span>
          </div>
        </div>
      </div>

      <!-- Breakdowns -->
      <div class="mt-6 grid grid-cols-1 lg:grid-cols-2 gap-4">
        <!-- Token breakdown -->
        <ACard>
          <h2 class="text-sm font-medium text-voceive-text-secondary">Token Breakdown</h2>
          <dl class="mt-4 space-y-3">
            <div class="flex items-center justify-between">
              <dt class="text-sm text-voceive-text-muted">Prompt tokens</dt>
              <dd class="text-sm font-medium text-voceive-text-primary">
                {{ formatNumber(usage.prompt_tokens) }}
              </dd>
            </div>
            <div class="flex items-center justify-between">
              <dt class="text-sm text-voceive-text-muted">Completion tokens</dt>
              <dd class="text-sm font-medium text-voceive-text-primary">
                {{ formatNumber(usage.completion_tokens) }}
              </dd>
            </div>
          </dl>
        </ACard>

        <!-- By operation -->
        <ACard v-if="usage.by_operation.length > 0">
          <h2 class="text-sm font-medium text-voceive-text-secondary">By Operation</h2>
          <dl class="mt-4 space-y-3">
            <div
              v-for="op in usage.by_operation"
              :key="op.operation"
              class="flex items-center justify-between"
            >
              <dt class="text-sm text-voceive-text-muted capitalize">{{ op.operation }}</dt>
              <dd class="text-sm text-voceive-text-primary">
                <span class="font-medium">{{ formatNumber(op.total_tokens) }}</span>
                <span class="text-voceive-text-muted ml-1">tokens</span>
                <span class="text-voceive-text-muted mx-1">&middot;</span>
                <span>{{ formatNumber(op.request_count) }}</span>
                <span class="text-voceive-text-muted ml-1">{{ op.request_count === 1 ? 'request' : 'requests' }}</span>
              </dd>
            </div>
          </dl>
        </ACard>

        <!-- By model -->
        <ACard v-if="usage.by_model.length > 0">
          <h2 class="text-sm font-medium text-voceive-text-secondary">By Model</h2>
          <dl class="mt-4 space-y-3">
            <div
              v-for="model in usage.by_model"
              :key="model.model"
              class="flex items-center justify-between"
            >
              <dt class="text-sm text-voceive-text-muted font-mono text-xs">{{ model.model }}</dt>
              <dd class="text-sm text-voceive-text-primary">
                <span class="font-medium">{{ formatNumber(model.total_tokens) }}</span>
                <span class="text-voceive-text-muted ml-1">tokens</span>
                <span class="text-voceive-text-muted mx-1">&middot;</span>
                <span>{{ formatCost(model.estimated_cost) }}</span>
              </dd>
            </div>
          </dl>
        </ACard>

        <!-- Daily activity (if data exists) -->
        <ACard v-if="usage.by_day.length > 0">
          <h2 class="text-sm font-medium text-voceive-text-secondary">Daily Activity</h2>
          <div class="mt-4 space-y-2 max-h-64 overflow-y-auto">
            <div
              v-for="day in usage.by_day"
              :key="day.date"
              class="flex items-center justify-between text-sm"
            >
              <span class="text-voceive-text-muted">{{ day.date }}</span>
              <span class="text-voceive-text-primary">
                <span class="font-medium">{{ formatNumber(day.total_tokens) }}</span>
                <span class="text-voceive-text-muted ml-1">tokens</span>
                <span class="text-voceive-text-muted mx-1">&middot;</span>
                <span>{{ formatNumber(day.request_count) }}</span>
                <span class="text-voceive-text-muted ml-1">{{ day.request_count === 1 ? 'req' : 'reqs' }}</span>
              </span>
            </div>
          </div>
        </ACard>
      </div>
    </template>
  </div>
</template>
