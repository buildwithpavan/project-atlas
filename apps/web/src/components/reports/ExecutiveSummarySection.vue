<script setup lang="ts">
/* eslint-disable no-undef */
import { ref, onMounted, computed } from 'vue'
import * as reportsApi from '@/api/reports'
import type { ExecutiveSummary } from '@/api/types'
import { ApiError } from '@/api/errors'
import { AButton } from '@/components/ui'

const summary = ref<ExecutiveSummary | null>(null)
const loading = ref(true)
const generating = ref(false)
const error = ref<string | null>(null)
const notFound = ref(false)

const stale = computed(() => summary.value?.stale ?? false)

async function fetchSummary() {
  loading.value = true
  error.value = null
  notFound.value = false
  try {
    const res = await reportsApi.getExecutiveSummary()
    summary.value = res.data
  } catch (err) {
    if (err instanceof ApiError && err.status === 404) {
      notFound.value = true
    } else if (err instanceof ApiError) {
      error.value = err.detail
    } else {
      error.value = 'Failed to load executive summary.'
    }
  } finally {
    loading.value = false
  }
}

async function generate() {
  generating.value = true
  error.value = null
  try {
    const res = await reportsApi.generateExecutiveSummary()
    summary.value = res.data
    notFound.value = false
  } catch (err) {
    if (err instanceof ApiError) {
      error.value = err.detail
    } else {
      error.value = 'Failed to generate executive summary.'
    }
  } finally {
    generating.value = false
  }
}

function formatDate(iso: string): string {
  try {
    return new Date(iso).toLocaleDateString(undefined, {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    })
  } catch {
    return iso
  }
}

function priorityClass(priority: string): string {
  if (priority === 'high') return 'text-voceive-error bg-voceive-error-subtle border-voceive-error/20'
  if (priority === 'medium') return 'text-voceive-warning bg-voceive-warning-subtle border-voceive-warning/20'
  return 'text-voceive-success bg-voceive-success-subtle border-voceive-success/20'
}

onMounted(fetchSummary)
</script>

<template>
  <section class="mt-6">
    <div class="flex items-center gap-2 mb-4">
      <div
        class="size-5 rounded bg-voceive-ai-subtle flex items-center justify-center"
        aria-hidden="true"
      >
        <svg
          class="size-3.5 text-voceive-ai"
          viewBox="0 0 20 20"
          fill="currentColor"
        >
          <path d="M10 1a.75.75 0 01.75.75v1.5a.75.75 0 01-1.5 0v-1.5A.75.75 0 0110 1zM5.05 3.05a.75.75 0 011.06 0l1.062 1.06A.75.75 0 116.11 5.173L5.05 4.11a.75.75 0 010-1.06zm9.9 0a.75.75 0 010 1.06l-1.06 1.062a.75.75 0 01-1.062-1.061l1.061-1.06a.75.75 0 011.06 0zM10 7a3 3 0 100 6 3 3 0 000-6zm-6.25 3a.75.75 0 01-.75-.75h-1.5a.75.75 0 010 1.5h1.5A.75.75 0 013.75 10zm14.5 0a.75.75 0 01-.75.75h-1.5a.75.75 0 010-1.5h1.5a.75.75 0 01.75.75zM5.05 16.95a.75.75 0 011.06 0l1.06-1.06a.75.75 0 10-1.06-1.062l-1.06 1.061a.75.75 0 010 1.06zm9.9 0a.75.75 0 010-1.06l-1.06-1.06a.75.75 0 10-1.062 1.06l1.061 1.06a.75.75 0 001.06 0zM10 15a.75.75 0 01.75.75v1.5a.75.75 0 01-1.5 0v-1.5A.75.75 0 0110 15z" />
        </svg>
      </div>
      <h2 class="text-base font-semibold text-voceive-text-primary">
        Executive Intelligence
      </h2>
      <span class="text-xs text-voceive-ai font-medium px-1.5 py-0.5 rounded bg-voceive-ai-subtle">
        AI
      </span>
    </div>

    <!-- Loading -->
    <div
      v-if="loading"
      class="bg-voceive-surface border border-voceive-border rounded-voceive-lg shadow-voceive-sm p-6 animate-pulse"
      data-testid="executive-summary-loading"
    >
      <div class="h-4 bg-voceive-border rounded w-3/4 mb-3" />
      <div class="h-4 bg-voceive-border rounded w-1/2" />
    </div>

    <!-- Error -->
    <div
      v-else-if="error"
      class="bg-voceive-error-subtle border border-voceive-error/20 rounded-voceive-lg shadow-voceive-sm p-6"
      data-testid="executive-summary-error"
    >
      <p class="text-sm text-voceive-error">{{ error }}</p>
      <AButton
        variant="ghost"
        size="sm"
        class="mt-3"
        @click="fetchSummary"
      >
        Retry
      </AButton>
    </div>

    <!-- No summary yet -->
    <div
      v-else-if="notFound"
      class="bg-voceive-surface border border-voceive-border rounded-voceive-lg shadow-voceive-sm p-6 text-center"
      data-testid="executive-summary-empty"
    >
      <p class="text-sm text-voceive-text-muted mb-3">
        No executive summary has been generated yet.
      </p>
      <AButton
        variant="primary"
        size="sm"
        :loading="generating"
        @click="generate"
      >
        Generate Executive Summary
      </AButton>
    </div>

    <!-- Summary content -->
    <div
      v-else-if="summary"
      class="bg-voceive-surface border border-voceive-border rounded-voceive-lg shadow-voceive-sm p-6"
      data-testid="executive-summary-content"
    >
      <!-- Stale banner -->
      <div
        v-if="stale"
        class="mb-4 p-3 rounded-lg bg-voceive-warning-subtle border border-voceive-warning/20 flex items-center justify-between"
        data-testid="executive-summary-stale"
      >
        <p class="text-sm text-voceive-warning">
          New analyses are available since this summary was generated.
        </p>
        <AButton
          variant="ghost"
          size="sm"
          :loading="generating"
          @click="generate"
        >
          Regenerate
        </AButton>
      </div>

      <!-- Summary text -->
      <p class="text-sm text-voceive-text-secondary leading-relaxed">
        {{ summary.summary }}
      </p>
      <p class="text-xs text-voceive-text-muted mt-2">
        Based on {{ summary.analyzed_ticket_count }} analyzed conversations
        · Generated {{ formatDate(summary.generated_at) }}
      </p>

      <!-- Key Findings -->
      <div
        v-if="summary.key_findings.length > 0"
        class="mt-5"
      >
        <h3 class="text-sm font-medium text-voceive-text-primary mb-2">Key Findings</h3>
        <ul class="space-y-2">
          <li
            v-for="(finding, i) in summary.key_findings"
            :key="i"
            class="text-sm border border-voceive-border rounded-lg p-3"
          >
            <div class="flex items-center gap-2">
              <span class="font-medium text-voceive-text-primary">{{ finding.title }}</span>
              <span
                v-if="finding.category"
                class="text-xs text-voceive-text-muted px-1.5 py-0.5 rounded bg-voceive-surface-muted"
              >
                {{ finding.category }}
              </span>
            </div>
            <p class="text-voceive-text-secondary mt-1">{{ finding.description }}</p>
            <p class="text-xs text-voceive-text-muted mt-1">
              {{ finding.evidence_count }} supporting conversation{{ finding.evidence_count === 1 ? '' : 's' }}
            </p>
          </li>
        </ul>
      </div>

      <!-- Attention Items -->
      <div
        v-if="summary.attention_items.length > 0"
        class="mt-5"
      >
        <h3 class="text-sm font-medium text-voceive-text-primary mb-2">Needs Attention</h3>
        <ul class="space-y-2">
          <li
            v-for="(item, i) in summary.attention_items"
            :key="i"
            class="text-sm border rounded-lg p-3"
            :class="priorityClass(item.priority)"
          >
            <div class="flex items-center gap-2">
              <span class="font-medium">{{ item.title }}</span>
              <span class="text-xs font-medium uppercase">{{ item.priority }}</span>
            </div>
            <p class="mt-1 opacity-80">{{ item.description }}</p>
            <p class="text-xs mt-1 opacity-60">
              {{ item.evidence_count }} supporting conversation{{ item.evidence_count === 1 ? '' : 's' }}
            </p>
          </li>
        </ul>
      </div>

      <!-- Recommended Actions -->
      <div
        v-if="summary.recommended_actions.length > 0"
        class="mt-5"
      >
        <h3 class="text-sm font-medium text-voceive-text-primary mb-2">Recommended Actions</h3>
        <ul class="space-y-2">
          <li
            v-for="(action, i) in summary.recommended_actions"
            :key="i"
            class="text-sm border border-voceive-border rounded-lg p-3"
          >
            <span class="font-medium text-voceive-text-primary">{{ action.title }}</span>
            <p class="text-voceive-text-secondary mt-1">{{ action.description }}</p>
            <p class="text-xs text-voceive-text-muted mt-1">
              {{ action.evidence_count }} supporting conversation{{ action.evidence_count === 1 ? '' : 's' }}
            </p>
          </li>
        </ul>
      </div>

      <!-- Regenerate button (when not stale) -->
      <div
        v-if="!stale"
        class="mt-4 flex justify-end"
      >
        <AButton
          variant="ghost"
          size="sm"
          :loading="generating"
          @click="generate"
        >
          Regenerate
        </AButton>
      </div>
    </div>
  </section>
</template>
