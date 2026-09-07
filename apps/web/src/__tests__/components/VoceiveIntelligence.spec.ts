import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import { createRouter, createWebHistory } from 'vue-router'
import VoceiveIntelligence from '@/components/reports/VoceiveIntelligence.vue'
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

function makeRouter() {
  return createRouter({
    history: createWebHistory(),
    routes: [
      { path: '/', component: { template: '<div />' } },
      { path: '/app/tickets', name: 'tickets', component: { template: '<div />' } },
    ],
  })
}

function mountComponent(report: Report) {
  const router = makeRouter()
  return mount(VoceiveIntelligence, {
    props: { report },
    global: { plugins: [router] },
  })
}

describe('VoceiveIntelligence', () => {
  it('renders the Voceive Intelligence heading', () => {
    const wrapper = mountComponent(makeReport())
    expect(wrapper.text()).toContain('Voceive Intelligence')
  })

  // -- Attention area -------------------------------------------------------

  it('shows attention section for high-priority signals', () => {
    // Large unanalyzed backlog → high attention
    const wrapper = mountComponent(makeReport({
      tickets: { total: 100, analyzed: 50, unanalyzed: 50 },
    }))
    expect(wrapper.text()).toContain('Attention')
  })

  it('hides attention section when no high/medium signals', () => {
    const wrapper = mountComponent(makeReport({
      tickets: { total: 10, analyzed: 10, unanalyzed: 0 },
      sentiment: {
        distribution: { positive: 8, neutral: 2 },
        percentages: { positive: 80, neutral: 20 },
      },
      classifications: { feature_requests: 0, bug_reports: 0, knowledge_gaps: 0 },
      categories: { distribution: {}, top: {} },
    }))
    expect(wrapper.text()).not.toContain('Attention')
  })

  // -- Key observations -----------------------------------------------------

  it('shows key observations section', () => {
    const wrapper = mountComponent(makeReport())
    expect(wrapper.text()).toContain('Key observations')
  })

  it('displays top sentiment observation', () => {
    const wrapper = mountComponent(makeReport())
    expect(wrapper.text()).toContain('Positive sentiment is the most common')
  })

  it('displays category observation', () => {
    const wrapper = mountComponent(makeReport())
    expect(wrapper.text()).toContain('Billing is the most common category')
  })

  it('displays metric values alongside observations', () => {
    const wrapper = mountComponent(makeReport())
    expect(wrapper.text()).toContain('30 conversations')
  })

  // -- Top categories -------------------------------------------------------

  it('renders top customer categories', () => {
    const wrapper = mountComponent(makeReport())
    expect(wrapper.text()).toContain('Top customer categories')
    expect(wrapper.text()).toContain('billing')
    expect(wrapper.text()).toContain('shipping')
    expect(wrapper.text()).toContain('login')
  })

  it('shows category percentages', () => {
    const wrapper = mountComponent(makeReport())
    // billing: 30/80 = 37.5%
    expect(wrapper.text()).toContain('37.5%')
  })

  it('hides categories when empty', () => {
    const wrapper = mountComponent(makeReport({
      categories: { distribution: {}, top: {} },
    }))
    expect(wrapper.text()).not.toContain('Top customer categories')
  })

  // -- Customer signals summary ---------------------------------------------

  it('renders signal summary', () => {
    const wrapper = mountComponent(makeReport())
    expect(wrapper.text()).toContain('Customer signals')
    expect(wrapper.text()).toContain('Feature requests')
    expect(wrapper.text()).toContain('Bug reports')
    expect(wrapper.text()).toContain('Knowledge gaps')
  })

  it('shows total signals', () => {
    const wrapper = mountComponent(makeReport())
    // 12 + 5 + 3 = 20
    expect(wrapper.text()).toContain('Total signals')
    expect(wrapper.text()).toContain('20')
  })

  it('shows "Identified in analyzed conversations" context', () => {
    const wrapper = mountComponent(makeReport())
    expect(wrapper.text()).toContain('Identified in analyzed conversations')
  })

  // -- Analysis status ------------------------------------------------------

  it('renders analysis coverage progress', () => {
    const wrapper = mountComponent(makeReport())
    expect(wrapper.text()).toContain('Analysis coverage')
    expect(wrapper.text()).toContain('80 / 100')
  })

  it('shows analysis progress bar', () => {
    const wrapper = mountComponent(makeReport())
    const bar = wrapper.find('[role="progressbar"]')
    expect(bar.exists()).toBe(true)
    expect(bar.attributes('aria-valuenow')).toBe('80')
    expect(bar.attributes('aria-valuemax')).toBe('100')
  })

  it('shows "all analyzed" message when unanalyzed is 0', () => {
    const wrapper = mountComponent(makeReport({
      tickets: { total: 50, analyzed: 50, unanalyzed: 0 },
    }))
    expect(wrapper.text()).toContain('All imported conversations have been analyzed')
  })

  it('shows unanalyzed message with tickets link', () => {
    const wrapper = mountComponent(makeReport())
    expect(wrapper.text()).toContain("haven't been analyzed yet")
    const link = wrapper.find('a[href="/app/tickets"]')
    expect(link.exists()).toBe(true)
    expect(link.text()).toContain('View tickets')
  })

  // -- Empty/minimal report -------------------------------------------------

  it('handles report with no analyzed data', () => {
    const wrapper = mountComponent(makeReport({
      tickets: { total: 10, analyzed: 0, unanalyzed: 10 },
      sentiment: { distribution: {}, percentages: {} },
      categories: { distribution: {}, top: {} },
      classifications: { feature_requests: 0, bug_reports: 0, knowledge_gaps: 0 },
    }))
    expect(wrapper.text()).toContain('Voceive Intelligence')
    expect(wrapper.text()).toContain('0 / 10')
  })

  it('handles report with all zeros', () => {
    const wrapper = mountComponent(makeReport({
      tickets: { total: 0, analyzed: 0, unanalyzed: 0 },
      sentiment: { distribution: {}, percentages: {} },
      categories: { distribution: {}, top: {} },
      classifications: { feature_requests: 0, bug_reports: 0, knowledge_gaps: 0 },
    }))
    expect(wrapper.text()).toContain('Voceive Intelligence')
    expect(wrapper.text()).toContain('0 / 0')
  })

  // -- Multiple simultaneous signals ----------------------------------------

  it('handles multiple high-attention signals', () => {
    const wrapper = mountComponent(makeReport({
      tickets: { total: 100, analyzed: 50, unanalyzed: 50 },
      classifications: { feature_requests: 15, bug_reports: 15, knowledge_gaps: 5 },
      sentiment: {
        distribution: { negative: 25, positive: 10, neutral: 5 },
        percentages: { negative: 62.5, positive: 25, neutral: 12.5 },
      },
    }))
    expect(wrapper.text()).toContain('Attention')
    // Should have multiple items in attention area
    const attentionSection = wrapper.text()
    expect(attentionSection).toContain('bug')
    expect(attentionSection).toContain('Negative')
  })
})
