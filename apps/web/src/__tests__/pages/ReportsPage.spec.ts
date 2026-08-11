import { describe, it, expect, beforeEach, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { createRouter, createWebHistory } from 'vue-router'
import ReportsPage from '@/pages/ReportsPage.vue'
import * as reportsApi from '@/api/reports'
import { ApiError } from '@/api/errors'
import type { Report, DataEnvelope } from '@/api/types'

vi.mock('@/api/reports')
vi.mock('@/api/auth', () => ({
  login: vi.fn(),
  register: vi.fn(),
  logout: vi.fn(),
  refresh: vi.fn(),
}))

const baseReport: Report = {
  metadata: { generated_at: '2026-08-01T12:00:00Z', organization_name: 'Acme' },
  tickets: { total: 150, analyzed: 120, unanalyzed: 30 },
  sentiment: {
    distribution: { positive: 60, neutral: 40, negative: 20 },
    percentages: { positive: 50, neutral: 33, negative: 17 },
  },
  categories: {
    distribution: { billing: 30, shipping: 25, login: 15 },
    top: { billing: 30, shipping: 25, login: 15 },
  },
  classifications: { feature_requests: 18, bug_reports: 7, knowledge_gaps: 5 },
  status_distribution: { open: 80, closed: 70 },
  priority_distribution: { high: 20, medium: 80, low: 50 },
  timeline: { '2026-07': 60, '2026-08': 90 },
}

function setupMock(response: DataEnvelope<Report> | Error = { data: baseReport }) {
  if (response instanceof Error) {
    vi.mocked(reportsApi.getReport).mockRejectedValue(response)
  } else {
    vi.mocked(reportsApi.getReport).mockResolvedValue(response)
  }
}

function makeRouter() {
  return createRouter({
    history: createWebHistory(),
    routes: [
      { path: '/app/reports', name: 'reports', component: ReportsPage },
      { path: '/app/tickets', name: 'tickets', component: { template: '<div />' } },
    ],
  })
}

async function mountPage() {
  const pinia = createPinia()
  setActivePinia(pinia)
  const router = makeRouter()
  await router.push('/app/reports')
  await router.isReady()

  const wrapper = mount(ReportsPage, {
    global: { plugins: [pinia, router] },
  })
  await flushPromises()
  return wrapper
}

describe('ReportsPage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  // -- Loading state --------------------------------------------------------

  it('shows loading skeleton initially', () => {
    setupMock()
    const pinia = createPinia()
    setActivePinia(pinia)
    const router = makeRouter()
    // Mount without awaiting flushPromises
    const wrapper = mount(ReportsPage, {
      global: { plugins: [pinia, router] },
    })
    expect(wrapper.findAll('.animate-pulse').length).toBeGreaterThan(0)
  })

  // -- Header ---------------------------------------------------------------

  it('renders report header', async () => {
    setupMock()
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('Customer Intelligence Report')
    expect(wrapper.text()).toContain('Patterns and insights')
  })

  it('shows generated timestamp', async () => {
    setupMock()
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('Generated')
  })

  // -- Executive Overview ---------------------------------------------------

  it('renders ticket metrics', async () => {
    setupMock()
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('Total Tickets')
    expect(wrapper.text()).toContain('150')
    expect(wrapper.text()).toContain('Analyzed')
    expect(wrapper.text()).toContain('120')
    expect(wrapper.text()).toContain('Unanalyzed')
    expect(wrapper.text()).toContain('30')
  })

  it('shows "All tickets analyzed" when unanalyzed is 0', async () => {
    setupMock({ data: { ...baseReport, tickets: { total: 100, analyzed: 100, unanalyzed: 0 } } })
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('All tickets analyzed')
  })

  // -- Sentiment ------------------------------------------------------------

  it('renders sentiment distribution', async () => {
    setupMock()
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('Customer Sentiment')
    expect(wrapper.text()).toContain('positive')
    expect(wrapper.text()).toContain('neutral')
    expect(wrapper.text()).toContain('negative')
  })

  it('handles empty sentiment', async () => {
    setupMock({
      data: {
        ...baseReport,
        sentiment: { distribution: {}, percentages: {} },
      },
    })
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('No sentiment data')
  })

  // -- Categories -----------------------------------------------------------

  it('renders category distribution', async () => {
    setupMock()
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('billing')
    expect(wrapper.text()).toContain('shipping')
    expect(wrapper.text()).toContain('login')
  })

  it('handles empty categories', async () => {
    setupMock({
      data: {
        ...baseReport,
        categories: { distribution: {}, top: {} },
      },
    })
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('No category data')
  })

  // -- Customer Signals -----------------------------------------------------

  it('renders feature requests', async () => {
    setupMock()
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('Feature Requests')
    expect(wrapper.text()).toContain('18')
  })

  it('renders bug reports', async () => {
    setupMock()
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('Bug Reports')
    expect(wrapper.text()).toContain('7')
  })

  it('renders knowledge gaps', async () => {
    setupMock()
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('Knowledge Gaps')
    expect(wrapper.text()).toContain('5')
  })

  it('has a link to tickets', async () => {
    setupMock()
    const wrapper = await mountPage()
    const link = wrapper.find('a[href="/app/tickets"]')
    expect(link.exists()).toBe(true)
    expect(link.text()).toContain('View all tickets')
  })

  // -- Status/Priority Distribution ----------------------------------------

  it('renders status distribution', async () => {
    setupMock()
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('Status Distribution')
    expect(wrapper.text()).toContain('open')
    expect(wrapper.text()).toContain('closed')
  })

  it('renders priority distribution', async () => {
    setupMock()
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('Priority Distribution')
    expect(wrapper.text()).toContain('high')
    expect(wrapper.text()).toContain('medium')
    expect(wrapper.text()).toContain('low')
  })

  it('handles empty status distribution', async () => {
    setupMock({ data: { ...baseReport, status_distribution: {} } })
    const wrapper = await mountPage()
    // The ReportDistribution component handles empty state
    const distCards = wrapper.findAll('.bg-atlas-surface')
    expect(distCards.length).toBeGreaterThan(0)
  })

  // -- Timeline -------------------------------------------------------------

  it('renders timeline', async () => {
    setupMock()
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('Customer Activity')
    expect(wrapper.text()).toContain('Ticket Activity')
  })

  it('hides timeline when empty', async () => {
    setupMock({ data: { ...baseReport, timeline: {} } })
    const wrapper = await mountPage()
    expect(wrapper.text()).not.toContain('Customer Activity')
  })

  // -- Empty state ----------------------------------------------------------

  it('shows empty state when total tickets is 0', async () => {
    setupMock({
      data: {
        ...baseReport,
        tickets: { total: 0, analyzed: 0, unanalyzed: 0 },
      },
    })
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('No report data yet')
    expect(wrapper.text()).toContain('Import customer tickets')
  })

  // -- Error state ----------------------------------------------------------

  it('shows error state on API failure', async () => {
    setupMock(
      new ApiError({
        type: '/errors/internal',
        title: 'Server Error',
        status: 500,
        detail: 'Database connection lost',
      }),
    )
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('Unable to load report')
    expect(wrapper.text()).toContain('Database connection lost')
  })

  it('error has retry button', async () => {
    setupMock(new Error('fail'))
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('Try again')
  })

  it('retry button calls API again', async () => {
    setupMock(new Error('fail'))
    const wrapper = await mountPage()

    vi.mocked(reportsApi.getReport).mockClear()
    setupMock()
    const retryBtn = wrapper.findAll('button').find(b => b.text().includes('Try again'))
    await retryBtn!.trigger('click')
    await flushPromises()

    expect(reportsApi.getReport).toHaveBeenCalledTimes(1)
    expect(wrapper.text()).toContain('Customer Intelligence Report')
  })

  // -- Refresh --------------------------------------------------------------

  it('refresh button triggers API call', async () => {
    setupMock()
    const wrapper = await mountPage()

    vi.mocked(reportsApi.getReport).mockClear()
    setupMock()

    const refreshBtn = wrapper.findAll('button').find(b => b.text().includes('Refresh'))
    await refreshBtn!.trigger('click')
    await flushPromises()

    expect(reportsApi.getReport).toHaveBeenCalledTimes(1)
  })

  // -- Partial data ---------------------------------------------------------

  it('handles zero feature requests gracefully', async () => {
    setupMock({
      data: {
        ...baseReport,
        classifications: { feature_requests: 0, bug_reports: 0, knowledge_gaps: 0 },
      },
    })
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('Feature Requests')
    expect(wrapper.text()).toContain('0')
  })
})
