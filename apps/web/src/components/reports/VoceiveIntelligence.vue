<script setup lang="ts">
import { computed } from 'vue'
import type { Report } from '@/api/types'
import { deriveInsights } from '@/utils/reportInsights'
import type { AttentionLevel } from '@/utils/reportInsights'

const props = defineProps<{
  report: Report
}>()

const insights = computed(() => deriveInsights(props.report))

const attentionItems = computed(() =>
  insights.value.observations.filter(o => o.level === 'high' || o.level === 'medium'),
)

const infoItems = computed(() =>
  insights.value.observations.filter(o => o.level === 'info'),
)

function levelLabel(level: AttentionLevel): string {
  if (level === 'high') return 'High'
  if (level === 'medium') return 'Medium'
  return 'Info'
}
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
        Voceive Intelligence
      </h2>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
      <!-- Left column: Attention + Observations -->
      <div class="space-y-4">
        <!-- Attention area -->
        <div
          v-if="attentionItems.length > 0"
          class="rounded-voceive-lg border border-voceive-border bg-voceive-surface p-5"
        >
          <h3 class="text-sm font-semibold text-voceive-text-primary mb-3">
            Attention
          </h3>
          <ul class="space-y-3">
            <li
              v-for="(item, i) in attentionItems"
              :key="'attn-' + i"
              class="flex items-start gap-3"
            >
              <span
                class="mt-0.5 inline-block size-2 rounded-full shrink-0"
                :class="item.level === 'high' ? 'bg-voceive-error' : 'bg-voceive-warning'"
                :aria-label="levelLabel(item.level) + ' attention'"
              />
              <div class="min-w-0 flex-1">
                <p class="text-sm text-voceive-text-primary">
                  {{ item.text }}
                </p>
                <p class="mt-0.5 text-xs text-voceive-text-muted tabular-nums">
                  {{ item.metricLabel }}: {{ item.metricValue }}
                </p>
              </div>
            </li>
          </ul>
        </div>

        <!-- Key observations -->
        <div
          v-if="infoItems.length > 0"
          class="rounded-voceive-lg border border-voceive-border bg-voceive-surface p-5"
        >
          <h3 class="text-sm font-semibold text-voceive-text-primary mb-3">
            Key observations
          </h3>
          <ul class="space-y-3">
            <li
              v-for="(item, i) in infoItems"
              :key="'obs-' + i"
              class="flex items-start gap-3"
            >
              <span
                class="mt-0.5 inline-block size-2 rounded-full shrink-0 bg-voceive-brand"
                aria-hidden="true"
              />
              <div class="min-w-0 flex-1">
                <p class="text-sm text-voceive-text-primary">
                  {{ item.text }}
                </p>
                <p class="mt-0.5 text-xs text-voceive-text-muted tabular-nums">
                  {{ item.metricLabel }}: {{ item.metricValue }}
                </p>
              </div>
            </li>
          </ul>
        </div>

        <!-- Analysis status -->
        <div class="rounded-voceive-lg border border-voceive-border bg-voceive-surface p-5">
          <h3 class="text-sm font-semibold text-voceive-text-primary mb-2">
            Analysis coverage
          </h3>
          <div class="flex items-center gap-3">
            <div class="flex-1 h-2 rounded-full bg-voceive-surface-muted overflow-hidden">
              <div
                class="h-full rounded-full bg-voceive-brand transition-all"
                :style="{ width: insights.analysisStatus.total > 0 ? (insights.analysisStatus.analyzed / insights.analysisStatus.total * 100) + '%' : '0%' }"
                role="progressbar"
                :aria-valuenow="insights.analysisStatus.analyzed"
                :aria-valuemax="insights.analysisStatus.total"
                aria-label="Analysis progress"
              />
            </div>
            <span class="text-xs text-voceive-text-muted tabular-nums whitespace-nowrap">
              {{ insights.analysisStatus.analyzed }} / {{ insights.analysisStatus.total }}
            </span>
          </div>
          <p class="mt-2 text-xs text-voceive-text-muted">
            <template v-if="insights.analysisStatus.allAnalyzed">
              All imported conversations have been analyzed.
            </template>
            <template v-else>
              Some customer conversations haven't been analyzed yet.
              <RouterLink
                to="/app/tickets"
                class="voceive-focus-ring text-voceive-brand hover:text-voceive-brand-hover transition-colors"
              >
                View tickets →
              </RouterLink>
            </template>
          </p>
        </div>
      </div>

      <!-- Right column: Top categories + Signals summary -->
      <div class="space-y-4">
        <!-- Top customer categories -->
        <div
          v-if="insights.topCategories.length > 0"
          class="rounded-voceive-lg border border-voceive-border bg-voceive-surface p-5"
        >
          <h3 class="text-sm font-semibold text-voceive-text-primary mb-3">
            Top customer categories
          </h3>
          <ul class="space-y-2.5">
            <li
              v-for="cat in insights.topCategories"
              :key="cat.name"
              class="flex items-center justify-between"
            >
              <span class="text-sm text-voceive-text-primary capitalize">
                {{ cat.name }}
              </span>
              <span class="text-xs text-voceive-text-muted tabular-nums">
                {{ cat.count }} · {{ cat.percentage }}%
              </span>
            </li>
          </ul>
        </div>

        <!-- Signals summary -->
        <div class="rounded-voceive-lg border border-voceive-border bg-voceive-surface p-5">
          <h3 class="text-sm font-semibold text-voceive-text-primary mb-3">
            Customer signals
          </h3>
          <p class="text-xs text-voceive-text-muted mb-3">
            Identified in analyzed conversations
          </p>
          <div class="space-y-2">
            <div class="flex items-center justify-between">
              <span class="text-sm text-voceive-text-primary">Feature requests</span>
              <span class="text-sm font-medium text-voceive-text-primary tabular-nums">{{ insights.signals.featureRequests }}</span>
            </div>
            <div class="flex items-center justify-between">
              <span class="text-sm text-voceive-text-primary">Bug reports</span>
              <span class="text-sm font-medium text-voceive-text-primary tabular-nums">{{ insights.signals.bugReports }}</span>
            </div>
            <div class="flex items-center justify-between">
              <span class="text-sm text-voceive-text-primary">Knowledge gaps</span>
              <span class="text-sm font-medium text-voceive-text-primary tabular-nums">{{ insights.signals.knowledgeGaps }}</span>
            </div>
          </div>
          <div class="mt-3 pt-3 border-t border-voceive-border flex items-center justify-between">
            <span class="text-sm font-medium text-voceive-text-primary">Total signals</span>
            <span class="text-sm font-semibold text-voceive-text-primary tabular-nums">{{ insights.signals.totalSignals }}</span>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>
