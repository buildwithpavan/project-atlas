<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import * as dashboardApi from '@/api/dashboard'
import * as reportsApi from '@/api/reports'
import type { Dashboard, Report } from '@/api/types'
import { ApiError } from '@/api/errors'
import { AButton } from '@/components/ui'
import MetricCard from '@/components/dashboard/MetricCard.vue'
import SentimentChart from '@/components/dashboard/SentimentChart.vue'
import CategoryChart from '@/components/dashboard/CategoryChart.vue'
import SignalCard from '@/components/dashboard/SignalCard.vue'
import ActivityChart from '@/components/dashboard/ActivityChart.vue'
import DashboardSkeleton from '@/components/dashboard/DashboardSkeleton.vue'
import DashboardEmptyState from '@/components/dashboard/DashboardEmptyState.vue'
import DashboardError from '@/components/dashboard/DashboardError.vue'

const loading = ref(true)
const error = ref<string | null>(null)
const dashboard = ref<Dashboard | null>(null)
const report = ref<Report | null>(null)

const isEmpty = computed(() =>
  dashboard.value !== null && dashboard.value.total_tickets === 0,
)

const analysisDescription = computed(() => {
  if (!dashboard.value) return ''
  const { total_tickets, analyzed_tickets } = dashboard.value
  if (analyzed_tickets === 0) return 'No tickets analyzed yet'
  if (analyzed_tickets === total_tickets) return 'All tickets analyzed'
  return `${total_tickets - analyzed_tickets} awaiting analysis`
})

async function fetchData() {
  loading.value = true
  error.value = null
  try {
    const [dashRes, reportRes] = await Promise.allSettled([
      dashboardApi.getDashboard(),
      reportsApi.getReport(),
    ])

    if (dashRes.status === 'fulfilled') {
      dashboard.value = dashRes.value.data
    } else {
      throw dashRes.reason
    }

    // Reports data is supplementary — don't fail the page if it errors
    if (reportRes.status === 'fulfilled') {
      report.value = reportRes.value.data
    }
  } catch (err) {
    if (err instanceof ApiError) {
      error.value = err.detail
    } else {
      error.value = 'Something went wrong while loading your dashboard.'
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
    <DashboardSkeleton v-if="loading" />

    <!-- Error state -->
    <DashboardError
      v-else-if="error"
      :message="error"
      @retry="fetchData"
    />

    <!-- Empty state -->
    <DashboardEmptyState v-else-if="isEmpty" />

    <!-- Dashboard content -->
    <template v-else-if="dashboard">
      <!-- Header -->
      <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-2">
        <div>
          <h1 class="text-2xl font-semibold text-atlas-text-primary">
            Customer Intelligence
          </h1>
          <p class="mt-1 text-sm text-atlas-text-muted">
            Understand what your customers are telling you.
          </p>
        </div>
        <AButton
          variant="ghost"
          size="sm"
          :loading="loading"
          @click="fetchData"
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

      <!-- KPI cards -->
      <div class="mt-6 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <MetricCard
          label="Total Tickets"
          :value="dashboard.total_tickets"
          description="Customer feedback collected"
        />
        <MetricCard
          label="Analyzed"
          :value="dashboard.analyzed_tickets"
          :description="analysisDescription"
        />
        <MetricCard
          label="Feature Requests"
          :value="dashboard.feature_requests"
          description="Customers asking for new capabilities"
        />
        <MetricCard
          label="Bug Reports"
          :value="dashboard.bug_reports"
          description="Customers reporting problems"
        />
      </div>

      <!-- Charts row -->
      <div class="mt-6 grid grid-cols-1 lg:grid-cols-2 gap-4">
        <SentimentChart :distribution="dashboard.sentiment_distribution" />
        <CategoryChart :categories="dashboard.top_categories" />
      </div>

      <!-- Customer signals -->
      <div class="mt-6 grid grid-cols-1 sm:grid-cols-2 gap-4">
        <SignalCard
          label="Feature Requests"
          :value="dashboard.feature_requests"
          description="Customers asking for new capabilities"
          variant="feature"
        />
        <SignalCard
          label="Bug Reports"
          :value="dashboard.bug_reports"
          description="Customers reporting problems"
          variant="bug"
        />
      </div>

      <!-- Activity timeline (from reports API) -->
      <div
        v-if="report?.timeline && Object.keys(report.timeline).length > 0"
        class="mt-6"
      >
        <ActivityChart :timeline="report.timeline" />
      </div>
    </template>
  </div>
</template>
