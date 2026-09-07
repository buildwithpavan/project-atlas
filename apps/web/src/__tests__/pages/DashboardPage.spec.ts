import { describe, it, expect, beforeEach, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { createRouter, createWebHistory } from 'vue-router'
import DashboardPage from '@/pages/DashboardPage.vue'
import * as dashboardApi from '@/api/dashboard'
import * as reportsApi from '@/api/reports'
import { ApiError } from '@/api/errors'
import type { Dashboard, Report, DataEnvelope } from '@/api/types'

vi.mock('@/api/dashboard')
vi.mock('@/api/reports')
// Auth module must be mocked because Pinia auth store calls setTokenAccessor etc.
vi.mock('@/api/auth', () => ({
  login: vi.fn(),
  register: vi.fn(),
  logout: vi.fn(),
  refresh: vi.fn(),
}))

const baseDashboard: Dashboard = {
  total_tickets: 150,
  analyzed_tickets: 120,
  sentiment_distribution: { positive: 60, neutral: 40, negative: 20 },
  top_categories: { billing: 30, shipping: 25, login: 15 },
  feature_requests: 18,
  bug_reports: 7,
}

const baseReport: Report = {
  metadata: { generated_at: '2026-08-01T00:00:00Z', organization_name: 'Acme' },
  tickets: { total: 150, analyzed: 120, unanalyzed: 30 },
  sentiment: {
    distribution: { positive: 60, neutral: 40, negative: 20 },
    percentages: { positive: 50, neutral: 33, negative: 17 },
  },
  categories: {
    distribution: { billing: 30, shipping: 25 },
    top: { billing: 30, shipping: 25 },
  },
  classifications: { feature_requests: 18, bug_reports: 7, knowledge_gaps: 3 },
  status_distribution: { open: 80, closed: 70 },
  priority_distribution: { high: 20, medium: 80, low: 50 },
  timeline: { '2026-07-01': 10, '2026-07-08': 15, '2026-07-15': 20 },
}

function setupMocks(
  dash: DataEnvelope<Dashboard> | Error = { data: baseDashboard },
  rep: DataEnvelope<Report> | Error = { data: baseReport },
) {
  if (dash instanceof Error) {
    vi.mocked(dashboardApi.getDashboard).mockRejectedValue(dash)
  } else {
    vi.mocked(dashboardApi.getDashboard).mockResolvedValue(dash)
  }
  if (rep instanceof Error) {
    vi.mocked(reportsApi.getReport).mockRejectedValue(rep)
  } else {
    vi.mocked(reportsApi.getReport).mockResolvedValue(rep)
  }
}

function mountPage() {
  const pinia = createPinia()
  setActivePinia(pinia)
  const router = createRouter({
    history: createWebHistory(),
    routes: [
      { path: '/', component: { template: '<div />' } },
      { path: '/app/import', name: 'import', component: { template: '<div />' } },
      { path: '/app/tickets', name: 'tickets', component: { template: '<div />' } },
    ],
  })
  return mount(DashboardPage, {
    global: { plugins: [pinia, router] },
  })
}

describe('DashboardPage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  // -- Loading state --------------------------------------------------------

  it('shows loading skeleton initially', () => {
    setupMocks()
    // Don't flush — check during load
    const wrapper = mountPage()
    expect(wrapper.findAll('.animate-pulse').length).toBeGreaterThan(0)
  })

  // -- Loaded state ---------------------------------------------------------

  it('renders dashboard header', async () => {
    setupMocks()
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('Customer Intelligence')
    expect(wrapper.text()).toContain('Understand what your customers are telling you')
  })

  it('renders KPI metric values', async () => {
    setupMocks()
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('150')
    expect(wrapper.text()).toContain('120')
    expect(wrapper.text()).toContain('18')
    expect(wrapper.text()).toContain('7')
  })

  it('renders KPI labels', async () => {
    setupMocks()
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('Total Tickets')
    expect(wrapper.text()).toContain('Analyzed')
    expect(wrapper.text()).toContain('Feature Requests')
    expect(wrapper.text()).toContain('Bug Reports')
  })

  it('renders sentiment chart with distribution data', async () => {
    setupMocks()
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('Customer Sentiment')
    expect(wrapper.text()).toContain('positive')
    expect(wrapper.text()).toContain('neutral')
    expect(wrapper.text()).toContain('negative')
  })

  it('renders category chart', async () => {
    setupMocks()
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('What Customers Are Talking About')
    expect(wrapper.text()).toContain('billing')
    expect(wrapper.text()).toContain('shipping')
  })

  it('renders signal cards', async () => {
    setupMocks()
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('Customers asking for new capabilities')
    expect(wrapper.text()).toContain('Customers reporting problems')
  })

  it('renders activity timeline from reports API', async () => {
    setupMocks()
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('Ticket Activity')
  })

  // -- Refresh --------------------------------------------------------------

  it('refresh button triggers another API call', async () => {
    setupMocks()
    const wrapper = mountPage()
    await flushPromises()

    vi.mocked(dashboardApi.getDashboard).mockClear()
    vi.mocked(reportsApi.getReport).mockClear()
    setupMocks()

    await wrapper.find('button').trigger('click')
    await flushPromises()

    expect(dashboardApi.getDashboard).toHaveBeenCalledTimes(1)
  })

  // -- Error state ----------------------------------------------------------

  it('shows error state on API failure', async () => {
    setupMocks(
      new ApiError({
        type: '/errors/internal',
        title: 'Server Error',
        status: 500,
        detail: 'Database connection lost',
      }),
    )
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('Unable to load dashboard')
    expect(wrapper.text()).toContain('Database connection lost')
  })

  it('error state has retry button', async () => {
    setupMocks(new Error('fail'))
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('Try again')
  })

  it('retry button calls API again', async () => {
    setupMocks(new Error('fail'))
    const wrapper = mountPage()
    await flushPromises()

    vi.mocked(dashboardApi.getDashboard).mockClear()
    setupMocks()
    await wrapper.find('button').trigger('click')
    await flushPromises()

    expect(dashboardApi.getDashboard).toHaveBeenCalledTimes(1)
  })

  // -- Empty state ----------------------------------------------------------

  it('shows empty state when total_tickets is 0', async () => {
    setupMocks({ data: { ...baseDashboard, total_tickets: 0 } })
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('No customer feedback yet')
    expect(wrapper.text()).toContain('Import customer tickets')
    const importLink = wrapper.find('a[href="/app/import"]')
    expect(importLink.exists()).toBe(true)
    expect(importLink.text()).toContain('Import Data')
  })

  // -- Partial data ---------------------------------------------------------

  it('handles missing sentiment categories', async () => {
    setupMocks({
      data: { ...baseDashboard, sentiment_distribution: { positive: 10 } },
    })
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('positive')
    expect(wrapper.text()).toContain('10')
  })

  it('handles empty categories', async () => {
    setupMocks({
      data: { ...baseDashboard, top_categories: {} },
    })
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('No category data')
  })

  it('handles zero feature requests and bug reports', async () => {
    setupMocks({
      data: { ...baseDashboard, feature_requests: 0, bug_reports: 0 },
    })
    const wrapper = mountPage()
    await flushPromises()

    // Should still render without breaking — just show 0
    expect(wrapper.text()).toContain('Feature Requests')
    expect(wrapper.text()).toContain('Bug Reports')
  })

  it('handles report API failure gracefully', async () => {
    setupMocks({ data: baseDashboard }, new Error('reports down'))
    const wrapper = mountPage()
    await flushPromises()

    // Dashboard should still render — reports are supplementary
    expect(wrapper.text()).toContain('Customer Intelligence')
    expect(wrapper.text()).toContain('150')
  })

  it('hides activity chart when no timeline data', async () => {
    setupMocks({ data: baseDashboard }, new Error('no report'))
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).not.toContain('Ticket Activity')
  })
})
