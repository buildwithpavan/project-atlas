<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import * as reportsApi from '@/api/reports'
import type { Report } from '@/api/types'
import { ApiError } from '@/api/errors'
import { AButton } from '@/components/ui'
import MetricCard from '@/components/dashboard/MetricCard.vue'
import SentimentChart from '@/components/dashboard/SentimentChart.vue'
import CategoryChart from '@/components/dashboard/CategoryChart.vue'
import SignalCard from '@/components/dashboard/SignalCard.vue'
import ActivityChart from '@/components/dashboard/ActivityChart.vue'
import ReportDistribution from '@/components/reports/ReportDistribution.vue'
import ReportSkeleton from '@/components/reports/ReportSkeleton.vue'
import ReportEmptyState from '@/components/reports/ReportEmptyState.vue'
import ReportError from '@/components/reports/ReportError.vue'

const loading = ref(true)
const error = ref<string | null>(null)
const report = ref<Report | null>(null)

const isEmpty = computed(() =>
  report.value !== null && report.value.tickets.total === 0,
)

function formatGeneratedAt(iso: string): string {
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

async function fetchReport() {
  loading.value = true
  error.value = null
  try {
    const res = await reportsApi.getReport()
    report.value = res.data
  } catch (err) {
    if (err instanceof ApiError) {
      error.value = err.detail
    } else {
      error.value = 'Something went wrong while loading your report.'
    }
  } finally {
    loading.value = false
  }
}

onMounted(fetchReport)
</script>

<template>
  <div>
    <!-- Loading skeleton -->
    <ReportSkeleton v-if="loading" />

    <!-- Error state -->
    <ReportError
      v-else-if="error"
      :message="error"
      @retry="fetchReport"
    />

    <!-- Empty state -->
    <ReportEmptyState v-else-if="isEmpty" />

    <!-- Report content -->
    <template v-else-if="report">
      <!-- Header -->
      <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-2">
        <div>
          <h1 class="text-2xl font-semibold text-atlas-text-primary">
            Customer Intelligence Report
          </h1>
          <p class="mt-1 text-sm text-atlas-text-muted">
            Patterns and insights from your customer feedback.
            <span v-if="report.metadata.generated_at">
              Generated {{ formatGeneratedAt(report.metadata.generated_at) }}.
            </span>
          </p>
        </div>
        <AButton
          variant="ghost"
          size="sm"
          :loading="loading"
          @click="fetchReport"
        >
          <svg
            class="size-4"
            viewBox="0 0 20 20"
            fill="currentColor"
            aria-hidden="true"
          >
            <path
              fill-rule="evenodd"
              d="M15.312 11.424a5.5 5.5 0 01-9.201 2.466l-.312-.311h2.433a.75.75 0 000-1.5H4.598a.75.75 0 00-.75.75v3.634a.75.75 0 001.5 0v-2.033l.262.263a7 7 0 0011.712-3.138.75.75 0 00-1.449-.393zm.176-6.348a.75.75 0 00-1.5 0v2.033l-.262-.263A7 7 0 002.014 9.984a.75.75 0 001.45.393 5.5 5.5 0 019.2-2.467l.313.311h-2.433a.75.75 0 000 1.5h3.634a.75.75 0 00.75-.75V5.337l-.44.001z"
              clip-rule="evenodd"
            />
          </svg>
          Refresh
        </AButton>
      </div>

      <!-- Executive Overview -->
      <section class="mt-6">
        <h2 class="text-base font-semibold text-atlas-text-primary mb-4">
          Executive Overview
        </h2>
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <MetricCard
            label="Total Tickets"
            :value="report.tickets.total"
            description="Customer feedback collected"
          />
          <MetricCard
            label="Analyzed"
            :value="report.tickets.analyzed"
            :description="report.tickets.unanalyzed > 0
              ? `${report.tickets.unanalyzed} awaiting analysis`
              : 'All tickets analyzed'"
          />
          <MetricCard
            label="Unanalyzed"
            :value="report.tickets.unanalyzed"
            description="Tickets pending AI analysis"
          />
        </div>
      </section>

      <!-- Sentiment + Categories -->
      <section class="mt-6">
        <h2 class="text-base font-semibold text-atlas-text-primary mb-4">
          Customer Sentiment &amp; Topics
        </h2>
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
          <SentimentChart :distribution="report.sentiment.distribution" />
          <CategoryChart :categories="report.categories.top" />
        </div>
      </section>

      <!-- Customer Signals -->
      <section class="mt-6">
        <div class="flex items-baseline justify-between mb-4">
          <h2 class="text-base font-semibold text-atlas-text-primary">
            Customer Signals
          </h2>
          <RouterLink
            :to="{ name: 'tickets' }"
            class="atlas-focus-ring rounded text-sm text-atlas-brand hover:text-atlas-brand-hover transition-colors"
          >
            View all tickets →
          </RouterLink>
        </div>
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <SignalCard
            label="Feature Requests"
            :value="report.classifications.feature_requests"
            description="Customers asking for new capabilities"
            variant="feature"
          />
          <SignalCard
            label="Bug Reports"
            :value="report.classifications.bug_reports"
            description="Customers reporting problems"
            variant="bug"
          />
          <div class="bg-atlas-surface border border-atlas-border rounded-atlas-lg shadow-atlas-sm p-5">
            <div class="flex items-start gap-3">
              <span
                class="inline-flex items-center justify-center size-9 rounded-atlas-md shrink-0 bg-atlas-warning-subtle"
                aria-hidden="true"
              >
                <svg
                  class="size-5 text-atlas-warning"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                >
                  <path
                    fill-rule="evenodd"
                    d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a.75.75 0 000 1.5h.253a.25.25 0 01.244.304l-.459 2.066A1.75 1.75 0 0010.747 15H11a.75.75 0 000-1.5h-.253a.25.25 0 01-.244-.304l.459-2.066A1.75 1.75 0 009.253 9H9z"
                    clip-rule="evenodd"
                  />
                </svg>
              </span>
              <div class="min-w-0 flex-1">
                <p class="text-sm font-medium text-atlas-text-secondary">
                  Knowledge Gaps
                </p>
                <p class="mt-1 text-2xl font-semibold text-atlas-text-primary tabular-nums">
                  {{ report.classifications.knowledge_gaps }}
                </p>
                <p class="mt-0.5 text-sm text-atlas-text-muted">
                  Customers needing clearer guidance
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- Ticket Operations -->
      <section class="mt-6">
        <h2 class="text-base font-semibold text-atlas-text-primary mb-4">
          Ticket Operations
        </h2>
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
          <ReportDistribution
            title="Status Distribution"
            :distribution="report.status_distribution"
          />
          <ReportDistribution
            title="Priority Distribution"
            :distribution="report.priority_distribution"
          />
        </div>
      </section>

      <!-- Activity Timeline -->
      <section
        v-if="Object.keys(report.timeline).length > 0"
        class="mt-6"
      >
        <h2 class="text-base font-semibold text-atlas-text-primary mb-4">
          Customer Activity
        </h2>
        <ActivityChart :timeline="report.timeline" />
      </section>
    </template>
  </div>
</template>
