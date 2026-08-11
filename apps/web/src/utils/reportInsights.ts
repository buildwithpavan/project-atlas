// ---------------------------------------------------------------------------
// Deterministic insight derivation from Report data
//
// Pure functions only — no API calls, no Vue/Pinia dependency.
// Every observation is traceable to a visible metric in the report.
// ---------------------------------------------------------------------------

import type { Report } from '@/api/types'

// -- Types ------------------------------------------------------------------

export type AttentionLevel = 'high' | 'medium' | 'info'

export interface Observation {
  text: string
  level: AttentionLevel
  /** Metric label shown beside the observation */
  metricLabel: string
  /** Metric value shown beside the observation */
  metricValue: string
}

export interface TopCategory {
  name: string
  count: number
  /** Percentage of analyzed conversations, rounded to 1 decimal */
  percentage: number
}

export interface ReportInsights {
  observations: Observation[]
  topCategories: TopCategory[]
  analysisStatus: {
    total: number
    analyzed: number
    unanalyzed: number
    allAnalyzed: boolean
  }
  signals: {
    featureRequests: number
    bugReports: number
    knowledgeGaps: number
    totalSignals: number
  }
}

// -- Thresholds (documented) ------------------------------------------------
//
// These thresholds determine attention levels. They are relative to the
// analyzed conversation count to avoid misleading absolute comparisons.
//
// High attention:
//   - Negative sentiment >= 30% of analyzed conversations
//   - Bug reports >= 20% of analyzed conversations
//   - Unanalyzed tickets >= 25% of total tickets
//
// Medium attention:
//   - Feature requests >= 10% of analyzed conversations
//   - A single category accounts for >= 40% of analyzed conversations
// ---------------------------------------------------------------------------

const NEGATIVE_SENTIMENT_HIGH_THRESHOLD = 0.30
const BUG_REPORT_HIGH_THRESHOLD = 0.20
const UNANALYZED_HIGH_THRESHOLD = 0.25
const FEATURE_REQUEST_MEDIUM_THRESHOLD = 0.10
const CATEGORY_CONCENTRATION_THRESHOLD = 0.40

// -- Helpers ----------------------------------------------------------------

function pct(part: number, total: number): number {
  if (total === 0) return 0
  return Math.round((part / total) * 1000) / 10 // 1 decimal
}

function sortedEntries(obj: Record<string, number>): [string, number][] {
  return Object.entries(obj).sort((a, b) => b[1] - a[1])
}

// -- Main derivation --------------------------------------------------------

export function deriveInsights(report: Report): ReportInsights {
  const { tickets, sentiment, categories, classifications } = report
  const analyzed = tickets.analyzed

  // --- Top categories ---
  const catEntries = sortedEntries(categories.top)
  const topCategories: TopCategory[] = catEntries.map(([name, count]) => ({
    name,
    count,
    percentage: pct(count, analyzed),
  }))

  // --- Observations + attention ---
  const observations: Observation[] = []

  // Sentiment observations
  const sentEntries = sortedEntries(sentiment.distribution)
  if (sentEntries.length > 0) {
    const [topSentiment, topSentimentCount] = sentEntries[0]
    const topSentimentPct = pct(topSentimentCount, analyzed)
    observations.push({
      text: `${capitalize(topSentiment)} sentiment is the most common across analyzed conversations.`,
      level: topSentiment === 'negative' && topSentimentPct / 100 >= NEGATIVE_SENTIMENT_HIGH_THRESHOLD
        ? 'high'
        : 'info',
      metricLabel: capitalize(topSentiment),
      metricValue: `${topSentimentPct}%`,
    })

    // Negative sentiment observation (if not already the top)
    const negativeCount = sentiment.distribution['negative'] ?? 0
    if (topSentiment !== 'negative' && negativeCount > 0) {
      const negativePct = pct(negativeCount, analyzed)
      observations.push({
        text: `Negative sentiment appears in ${negativePct}% of analyzed conversations.`,
        level: negativePct / 100 >= NEGATIVE_SENTIMENT_HIGH_THRESHOLD ? 'high' : 'info',
        metricLabel: 'Negative',
        metricValue: `${negativePct}%`,
      })
    }
  }

  // Top category observation
  if (catEntries.length > 0) {
    const [topCatName, topCatCount] = catEntries[0]
    const topCatPct = pct(topCatCount, analyzed)
    observations.push({
      text: `${capitalize(topCatName)} is the most common category in analyzed conversations.`,
      level: topCatPct / 100 >= CATEGORY_CONCENTRATION_THRESHOLD ? 'medium' : 'info',
      metricLabel: capitalize(topCatName),
      metricValue: `${topCatCount} conversations`,
    })
  }

  // Bug reports
  if (classifications.bug_reports > 0) {
    const bugPct = pct(classifications.bug_reports, analyzed)
    observations.push({
      text: `${classifications.bug_reports} bug ${classifications.bug_reports === 1 ? 'report was' : 'reports were'} identified across analyzed conversations.`,
      level: analyzed > 0 && bugPct / 100 >= BUG_REPORT_HIGH_THRESHOLD ? 'high' : 'info',
      metricLabel: 'Bug reports',
      metricValue: String(classifications.bug_reports),
    })
  }

  // Feature requests
  if (classifications.feature_requests > 0) {
    const featurePct = pct(classifications.feature_requests, analyzed)
    observations.push({
      text: `${classifications.feature_requests} feature ${classifications.feature_requests === 1 ? 'request was' : 'requests were'} identified.`,
      level: analyzed > 0 && featurePct / 100 >= FEATURE_REQUEST_MEDIUM_THRESHOLD ? 'medium' : 'info',
      metricLabel: 'Feature requests',
      metricValue: String(classifications.feature_requests),
    })
  }

  // Knowledge gaps
  if (classifications.knowledge_gaps > 0) {
    observations.push({
      text: `${classifications.knowledge_gaps} conversation${classifications.knowledge_gaps === 1 ? '' : 's'} suggest customers need clearer guidance.`,
      level: 'info',
      metricLabel: 'Knowledge gaps',
      metricValue: String(classifications.knowledge_gaps),
    })
  }

  // Unanalyzed backlog
  if (tickets.unanalyzed > 0) {
    const unanalyzedPct = pct(tickets.unanalyzed, tickets.total)
    observations.push({
      text: `${tickets.unanalyzed} conversation${tickets.unanalyzed === 1 ? ' has' : 's have'} not been analyzed yet.`,
      level: tickets.total > 0 && unanalyzedPct / 100 >= UNANALYZED_HIGH_THRESHOLD ? 'high' : 'medium',
      metricLabel: 'Unanalyzed',
      metricValue: `${tickets.unanalyzed} of ${tickets.total}`,
    })
  }

  // --- Sort observations: high first, then medium, then info ---
  const levelOrder: Record<AttentionLevel, number> = { high: 0, medium: 1, info: 2 }
  observations.sort((a, b) => levelOrder[a.level] - levelOrder[b.level])

  return {
    observations,
    topCategories,
    analysisStatus: {
      total: tickets.total,
      analyzed: tickets.analyzed,
      unanalyzed: tickets.unanalyzed,
      allAnalyzed: tickets.unanalyzed === 0,
    },
    signals: {
      featureRequests: classifications.feature_requests,
      bugReports: classifications.bug_reports,
      knowledgeGaps: classifications.knowledge_gaps,
      totalSignals: classifications.feature_requests + classifications.bug_reports + classifications.knowledge_gaps,
    },
  }
}

// -- Utilities --------------------------------------------------------------

function capitalize(s: string): string {
  if (!s) return s
  return s.charAt(0).toUpperCase() + s.slice(1)
}
