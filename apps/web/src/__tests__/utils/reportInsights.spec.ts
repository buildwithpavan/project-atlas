import { describe, it, expect } from 'vitest'
import { deriveInsights } from '@/utils/reportInsights'
import type { Report } from '@/api/types'

function makeReport(overrides: Partial<Report> = {}): Report {
  return {
    metadata: { generated_at: '2026-08-01T12:00:00Z', organization_name: 'Acme' },
    tickets: { total: 100, analyzed: 80, unanalyzed: 20 },
    sentiment: {
      distribution: { positive: 40, neutral: 25, negative: 15 },
      percentages: { positive: 50, neutral: 31.3, negative: 18.8 },
    },
    categories: {
      distribution: { billing: 30, shipping: 20, login: 10 },
      top: { billing: 30, shipping: 20, login: 10 },
    },
    classifications: { feature_requests: 12, bug_reports: 5, knowledge_gaps: 3 },
    status_distribution: { open: 60, closed: 40 },
    priority_distribution: { high: 10, medium: 50, low: 40 },
    timeline: { '2026-07': 40, '2026-08': 60 },
    ...overrides,
  }
}

describe('deriveInsights', () => {
  // -- Top categories -------------------------------------------------------

  it('returns top categories sorted by count', () => {
    const result = deriveInsights(makeReport())
    expect(result.topCategories[0].name).toBe('billing')
    expect(result.topCategories[0].count).toBe(30)
    expect(result.topCategories[1].name).toBe('shipping')
    expect(result.topCategories[2].name).toBe('login')
  })

  it('calculates category percentage of analyzed conversations', () => {
    const result = deriveInsights(makeReport())
    // billing: 30 / 80 * 100 = 37.5%
    expect(result.topCategories[0].percentage).toBe(37.5)
  })

  it('returns empty categories when none present', () => {
    const result = deriveInsights(makeReport({
      categories: { distribution: {}, top: {} },
    }))
    expect(result.topCategories).toHaveLength(0)
  })

  // -- Sentiment observations -----------------------------------------------

  it('identifies top sentiment', () => {
    const result = deriveInsights(makeReport())
    const sentObs = result.observations.find(o => o.text.includes('most common'))
    expect(sentObs).toBeTruthy()
    expect(sentObs!.text).toContain('Positive')
  })

  it('flags high attention when negative is dominant and above threshold', () => {
    const result = deriveInsights(makeReport({
      sentiment: {
        distribution: { negative: 30, positive: 10, neutral: 5 },
        percentages: { negative: 66.7, positive: 22.2, neutral: 11.1 },
      },
      tickets: { total: 50, analyzed: 45, unanalyzed: 5 },
    }))
    const sentObs = result.observations.find(o => o.text.includes('Negative sentiment is the most common'))
    expect(sentObs).toBeTruthy()
    expect(sentObs!.level).toBe('high')
  })

  it('adds separate negative sentiment observation when not top', () => {
    const result = deriveInsights(makeReport({
      sentiment: {
        distribution: { positive: 50, negative: 10, neutral: 20 },
        percentages: { positive: 62.5, negative: 12.5, neutral: 25 },
      },
    }))
    const negObs = result.observations.find(o => o.text.includes('Negative sentiment appears'))
    expect(negObs).toBeTruthy()
    expect(negObs!.metricValue).toContain('%')
  })

  it('handles empty sentiment', () => {
    const result = deriveInsights(makeReport({
      sentiment: { distribution: {}, percentages: {} },
    }))
    const sentObs = result.observations.find(o => o.text.includes('sentiment'))
    expect(sentObs).toBeUndefined()
  })

  // -- Bug reports ----------------------------------------------------------

  it('includes bug report observation', () => {
    const result = deriveInsights(makeReport())
    const bugObs = result.observations.find(o => o.text.includes('bug'))
    expect(bugObs).toBeTruthy()
    expect(bugObs!.metricValue).toBe('5')
  })

  it('flags high attention for significant bug count', () => {
    const result = deriveInsights(makeReport({
      classifications: { feature_requests: 2, bug_reports: 20, knowledge_gaps: 1 },
      tickets: { total: 100, analyzed: 80, unanalyzed: 20 },
    }))
    const bugObs = result.observations.find(o => o.text.includes('bug'))
    expect(bugObs!.level).toBe('high')
  })

  it('omits bug observation when count is 0', () => {
    const result = deriveInsights(makeReport({
      classifications: { feature_requests: 5, bug_reports: 0, knowledge_gaps: 2 },
    }))
    const bugObs = result.observations.find(o => o.text.includes('bug'))
    expect(bugObs).toBeUndefined()
  })

  // -- Feature requests -----------------------------------------------------

  it('includes feature request observation', () => {
    const result = deriveInsights(makeReport())
    const frObs = result.observations.find(o => o.text.includes('feature'))
    expect(frObs).toBeTruthy()
    expect(frObs!.metricValue).toBe('12')
  })

  it('flags medium attention for significant feature request volume', () => {
    const result = deriveInsights(makeReport({
      classifications: { feature_requests: 15, bug_reports: 1, knowledge_gaps: 0 },
      tickets: { total: 100, analyzed: 80, unanalyzed: 20 },
    }))
    const frObs = result.observations.find(o => o.text.includes('feature'))
    expect(frObs!.level).toBe('medium')
  })

  it('omits feature request observation when count is 0', () => {
    const result = deriveInsights(makeReport({
      classifications: { feature_requests: 0, bug_reports: 3, knowledge_gaps: 1 },
    }))
    const frObs = result.observations.find(o => o.text.includes('feature'))
    expect(frObs).toBeUndefined()
  })

  // -- Knowledge gaps -------------------------------------------------------

  it('includes knowledge gap observation', () => {
    const result = deriveInsights(makeReport())
    const kgObs = result.observations.find(o => o.text.includes('guidance'))
    expect(kgObs).toBeTruthy()
    expect(kgObs!.metricValue).toBe('3')
  })

  it('omits knowledge gap observation when count is 0', () => {
    const result = deriveInsights(makeReport({
      classifications: { feature_requests: 5, bug_reports: 2, knowledge_gaps: 0 },
    }))
    const kgObs = result.observations.find(o => o.text.includes('guidance'))
    expect(kgObs).toBeUndefined()
  })

  // -- Unanalyzed backlog ---------------------------------------------------

  it('includes unanalyzed observation', () => {
    const result = deriveInsights(makeReport())
    const uObs = result.observations.find(o => o.text.includes('not been analyzed'))
    expect(uObs).toBeTruthy()
    expect(uObs!.metricValue).toBe('20 of 100')
  })

  it('flags high attention for large unanalyzed backlog', () => {
    const result = deriveInsights(makeReport({
      tickets: { total: 100, analyzed: 50, unanalyzed: 50 },
    }))
    const uObs = result.observations.find(o => o.text.includes('not been analyzed'))
    expect(uObs!.level).toBe('high')
  })

  it('omits unanalyzed observation when all analyzed', () => {
    const result = deriveInsights(makeReport({
      tickets: { total: 100, analyzed: 100, unanalyzed: 0 },
    }))
    const uObs = result.observations.find(o => o.text.includes('not been analyzed'))
    expect(uObs).toBeUndefined()
  })

  // -- Analysis status ------------------------------------------------------

  it('returns correct analysis status', () => {
    const result = deriveInsights(makeReport())
    expect(result.analysisStatus).toEqual({
      total: 100,
      analyzed: 80,
      unanalyzed: 20,
      allAnalyzed: false,
    })
  })

  it('allAnalyzed is true when unanalyzed is 0', () => {
    const result = deriveInsights(makeReport({
      tickets: { total: 50, analyzed: 50, unanalyzed: 0 },
    }))
    expect(result.analysisStatus.allAnalyzed).toBe(true)
  })

  // -- Signals summary ------------------------------------------------------

  it('returns signal totals', () => {
    const result = deriveInsights(makeReport())
    expect(result.signals.featureRequests).toBe(12)
    expect(result.signals.bugReports).toBe(5)
    expect(result.signals.knowledgeGaps).toBe(3)
    expect(result.signals.totalSignals).toBe(20)
  })

  // -- Sorting --------------------------------------------------------------

  it('sorts observations by attention level (high first)', () => {
    const result = deriveInsights(makeReport({
      tickets: { total: 100, analyzed: 50, unanalyzed: 50 },
      classifications: { feature_requests: 15, bug_reports: 15, knowledge_gaps: 3 },
      sentiment: {
        distribution: { negative: 20, positive: 10, neutral: 5 },
        percentages: { negative: 57.1, positive: 28.6, neutral: 14.3 },
      },
    }))
    const levels = result.observations.map(o => o.level)
    const highIdx = levels.indexOf('high')
    const mediumIdx = levels.indexOf('medium')
    const infoIdx = levels.indexOf('info')
    if (highIdx >= 0 && mediumIdx >= 0) {
      expect(highIdx).toBeLessThan(mediumIdx)
    }
    if (mediumIdx >= 0 && infoIdx >= 0) {
      expect(mediumIdx).toBeLessThan(infoIdx)
    }
  })

  // -- Category concentration -----------------------------------------------

  it('flags medium attention for concentrated category', () => {
    const result = deriveInsights(makeReport({
      categories: { distribution: { billing: 40 }, top: { billing: 40 } },
      tickets: { total: 80, analyzed: 80, unanalyzed: 0 },
    }))
    const catObs = result.observations.find(o => o.text.includes('Billing'))
    expect(catObs!.level).toBe('medium')
  })

  // -- Edge case: no analyzed tickets ---------------------------------------

  it('handles zero analyzed tickets gracefully', () => {
    const result = deriveInsights(makeReport({
      tickets: { total: 10, analyzed: 0, unanalyzed: 10 },
      sentiment: { distribution: {}, percentages: {} },
      categories: { distribution: {}, top: {} },
      classifications: { feature_requests: 0, bug_reports: 0, knowledge_gaps: 0 },
    }))
    expect(result.topCategories).toHaveLength(0)
    expect(result.observations.length).toBeGreaterThan(0) // at least unanalyzed
  })

  // -- Edge case: empty report ----------------------------------------------

  it('handles empty report (no tickets)', () => {
    const result = deriveInsights(makeReport({
      tickets: { total: 0, analyzed: 0, unanalyzed: 0 },
      sentiment: { distribution: {}, percentages: {} },
      categories: { distribution: {}, top: {} },
      classifications: { feature_requests: 0, bug_reports: 0, knowledge_gaps: 0 },
      timeline: {},
    }))
    expect(result.observations).toHaveLength(0)
    expect(result.topCategories).toHaveLength(0)
    expect(result.signals.totalSignals).toBe(0)
  })

  // -- Singular forms -------------------------------------------------------

  it('uses singular form for 1 bug report', () => {
    const result = deriveInsights(makeReport({
      classifications: { feature_requests: 0, bug_reports: 1, knowledge_gaps: 0 },
    }))
    const bugObs = result.observations.find(o => o.text.includes('bug'))
    expect(bugObs!.text).toContain('report was')
  })

  it('uses singular form for 1 feature request', () => {
    const result = deriveInsights(makeReport({
      classifications: { feature_requests: 1, bug_reports: 0, knowledge_gaps: 0 },
    }))
    const frObs = result.observations.find(o => o.text.includes('feature'))
    expect(frObs!.text).toContain('request was')
  })

  it('uses singular form for 1 unanalyzed ticket', () => {
    const result = deriveInsights(makeReport({
      tickets: { total: 100, analyzed: 99, unanalyzed: 1 },
    }))
    const uObs = result.observations.find(o => o.text.includes('not been analyzed'))
    expect(uObs!.text).toContain('conversation has')
  })
})
