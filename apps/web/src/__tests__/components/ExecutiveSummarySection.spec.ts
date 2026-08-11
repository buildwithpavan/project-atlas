import { describe, it, expect, beforeEach, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import ExecutiveSummarySection from '@/components/reports/ExecutiveSummarySection.vue'
import * as reportsApi from '@/api/reports'
import { ApiError } from '@/api/errors'
import type { ExecutiveSummary, DataEnvelope } from '@/api/types'

vi.mock('@/api/reports')

const baseSummary: ExecutiveSummary = {
  id: '123e4567-e89b-12d3-a456-426614174000',
  summary: 'Customer feedback centers on billing and shipping concerns.',
  key_findings: [
    { title: 'Billing issues', description: 'Top concern across conversations', evidence_count: 15, category: 'billing' },
    { title: 'Shipping delays', description: 'Growing trend in recent weeks', evidence_count: 8 },
  ],
  attention_items: [
    { title: 'Bug reports rising', description: 'Multiple new bug reports detected', priority: 'high', evidence_count: 5 },
  ],
  recommended_actions: [
    { title: 'Review billing UX', description: 'Consider simplifying billing flow', evidence_count: 15 },
  ],
  analyzed_ticket_count: 50,
  generated_at: '2026-08-11T12:00:00Z',
  stale: false,
}

function setupGetMock(response: DataEnvelope<ExecutiveSummary> | Error = { data: baseSummary }) {
  if (response instanceof Error) {
    vi.mocked(reportsApi.getExecutiveSummary).mockRejectedValue(response)
  } else {
    vi.mocked(reportsApi.getExecutiveSummary).mockResolvedValue(response)
  }
}

function setupGenerateMock(response: DataEnvelope<ExecutiveSummary> | Error = { data: baseSummary }) {
  if (response instanceof Error) {
    vi.mocked(reportsApi.generateExecutiveSummary).mockRejectedValue(response)
  } else {
    vi.mocked(reportsApi.generateExecutiveSummary).mockResolvedValue(response)
  }
}

async function mountComponent() {
  const wrapper = mount(ExecutiveSummarySection)
  await flushPromises()
  return wrapper
}

describe('ExecutiveSummarySection', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  // -- Loading state --------------------------------------------------------

  it('shows loading skeleton initially', () => {
    setupGetMock()
    const wrapper = mount(ExecutiveSummarySection)
    expect(wrapper.find('[data-testid="executive-summary-loading"]').exists()).toBe(true)
  })

  // -- Summary display ------------------------------------------------------

  it('displays summary content when loaded', async () => {
    setupGetMock()
    const wrapper = await mountComponent()

    expect(wrapper.find('[data-testid="executive-summary-content"]').exists()).toBe(true)
    expect(wrapper.text()).toContain('Customer feedback centers on billing')
    expect(wrapper.text()).toContain('50 analyzed conversations')
  })

  it('displays key findings', async () => {
    setupGetMock()
    const wrapper = await mountComponent()

    expect(wrapper.text()).toContain('Key Findings')
    expect(wrapper.text()).toContain('Billing issues')
    expect(wrapper.text()).toContain('Shipping delays')
    expect(wrapper.text()).toContain('billing')
    expect(wrapper.text()).toContain('15 supporting conversations')
  })

  it('displays attention items with priority', async () => {
    setupGetMock()
    const wrapper = await mountComponent()

    expect(wrapper.text()).toContain('Needs Attention')
    expect(wrapper.text()).toContain('Bug reports rising')
    expect(wrapper.text()).toContain('high')
  })

  it('displays recommended actions', async () => {
    setupGetMock()
    const wrapper = await mountComponent()

    expect(wrapper.text()).toContain('Recommended Actions')
    expect(wrapper.text()).toContain('Review billing UX')
  })

  it('shows singular form for evidence_count of 1', async () => {
    const single = {
      ...baseSummary,
      key_findings: [{ title: 'Single', description: 'One', evidence_count: 1 }],
      attention_items: [],
      recommended_actions: [],
    }
    setupGetMock({ data: single })
    const wrapper = await mountComponent()

    expect(wrapper.text()).toContain('1 supporting conversation')
    expect(wrapper.text()).not.toContain('1 supporting conversations')
  })

  // -- Empty state ----------------------------------------------------------

  it('shows empty state when no summary exists (404)', async () => {
    setupGetMock(new ApiError({ type: '/errors/not-found', title: 'Not Found', status: 404, detail: 'Not found' }))
    const wrapper = await mountComponent()

    expect(wrapper.find('[data-testid="executive-summary-empty"]').exists()).toBe(true)
    expect(wrapper.text()).toContain('No executive summary has been generated')
    expect(wrapper.text()).toContain('Generate Executive Summary')
  })

  // -- Error state ----------------------------------------------------------

  it('shows error state on API failure', async () => {
    setupGetMock(new ApiError({ type: '/errors/server', title: 'Error', status: 500, detail: 'Server error' }))
    const wrapper = await mountComponent()

    expect(wrapper.find('[data-testid="executive-summary-error"]').exists()).toBe(true)
    expect(wrapper.text()).toContain('Server error')
  })

  it('shows generic error for non-API errors', async () => {
    setupGetMock(new Error('Network failure'))
    const wrapper = await mountComponent()

    expect(wrapper.find('[data-testid="executive-summary-error"]').exists()).toBe(true)
    expect(wrapper.text()).toContain('Failed to load executive summary')
  })

  // -- Staleness ------------------------------------------------------------

  it('shows stale banner when summary is stale', async () => {
    setupGetMock({ data: { ...baseSummary, stale: true } })
    const wrapper = await mountComponent()

    expect(wrapper.find('[data-testid="executive-summary-stale"]').exists()).toBe(true)
    expect(wrapper.text()).toContain('New analyses are available')
  })

  it('does not show stale banner when summary is fresh', async () => {
    setupGetMock()
    const wrapper = await mountComponent()

    expect(wrapper.find('[data-testid="executive-summary-stale"]').exists()).toBe(false)
  })

  // -- Generate action ------------------------------------------------------

  it('generates summary from empty state', async () => {
    setupGetMock(new ApiError({ type: '/errors/not-found', title: 'Not Found', status: 404, detail: 'Not found' }))
    setupGenerateMock()
    const wrapper = await mountComponent()

    await wrapper.find('[data-testid="executive-summary-empty"] button').trigger('click')
    await flushPromises()

    expect(reportsApi.generateExecutiveSummary).toHaveBeenCalled()
    expect(wrapper.find('[data-testid="executive-summary-content"]').exists()).toBe(true)
  })

  it('regenerates from stale state', async () => {
    const staleSummary = { ...baseSummary, stale: true }
    setupGetMock({ data: staleSummary })
    setupGenerateMock({ data: { ...baseSummary, stale: false } })
    const wrapper = await mountComponent()

    await wrapper.find('[data-testid="executive-summary-stale"] button').trigger('click')
    await flushPromises()

    expect(reportsApi.generateExecutiveSummary).toHaveBeenCalled()
  })

  it('shows error when generation fails', async () => {
    setupGetMock(new ApiError({ type: '/errors/not-found', title: 'Not Found', status: 404, detail: 'Not found' }))
    setupGenerateMock(new ApiError({ type: '/errors/validation', title: 'Error', status: 422, detail: 'No analyzed conversations' }))
    const wrapper = await mountComponent()

    await wrapper.find('[data-testid="executive-summary-empty"] button').trigger('click')
    await flushPromises()

    expect(wrapper.text()).toContain('No analyzed conversations')
  })

  // -- Heading and AI badge -------------------------------------------------

  it('renders the Executive Intelligence heading with AI badge', async () => {
    setupGetMock()
    const wrapper = await mountComponent()

    expect(wrapper.text()).toContain('Executive Intelligence')
    expect(wrapper.text()).toContain('AI')
  })
})
