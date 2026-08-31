import { describe, it, expect, beforeEach, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { createRouter, createWebHistory } from 'vue-router'
import AiUsagePage from '@/pages/AiUsagePage.vue'
import * as aiApi from '@/api/ai'
import { ApiError } from '@/api/errors'
import type { AiQuota, AiUsage, DataEnvelope } from '@/api/types'

vi.mock('@/api/ai')
vi.mock('@/api/auth', () => ({
  login: vi.fn(),
  register: vi.fn(),
  logout: vi.fn(),
  refresh: vi.fn(),
}))

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const baseQuota: AiQuota = {
  ai_monthly_token_limit: 500000,
  ai_monthly_cost_limit: 50.0,
  ai_quota_reserved_tokens: 0,
  period: '2026-08',
  current_month: {
    tokens_used: 125000,
    cost_used: 12.5,
    tokens_remaining: 375000,
    cost_remaining: 37.5,
    token_percentage_used: 25.0,
    cost_percentage_used: 25.0,
  },
}

const baseUsage: AiUsage = {
  period: '2026-08',
  tokens: {
    used: 125000,
    limit: 500000,
    remaining: 375000,
    percentage_used: 25.0,
  },
  cost: {
    used: 12.5,
    limit: 50.0,
    remaining: 37.5,
    percentage_used: 25.0,
  },
  prompt_tokens: 80000,
  completion_tokens: 45000,
  request_count: 42,
  average_latency_ms: 1250.5,
  by_operation: [
    {
      operation: 'chat',
      total_tokens: 100000,
      prompt_tokens: 60000,
      completion_tokens: 40000,
      estimated_cost: 10.0,
      request_count: 30,
      average_latency_ms: 1500.0,
    },
    {
      operation: 'embedding',
      total_tokens: 25000,
      prompt_tokens: 20000,
      completion_tokens: 5000,
      estimated_cost: 2.5,
      request_count: 12,
      average_latency_ms: 500.0,
    },
  ],
  by_model: [
    {
      model: 'gpt-4o',
      total_tokens: 100000,
      estimated_cost: 10.0,
      request_count: 30,
    },
    {
      model: 'text-embedding-3-small',
      total_tokens: 25000,
      estimated_cost: 2.5,
      request_count: 12,
    },
  ],
  by_user: [
    {
      user_id: 'user-1',
      email: 'alice@example.com',
      total_tokens: 75000,
      estimated_cost: 7.5,
      request_count: 25,
    },
  ],
  by_day: [
    {
      date: '2026-08-15',
      total_tokens: 50000,
      estimated_cost: 5.0,
      request_count: 15,
    },
    {
      date: '2026-08-16',
      total_tokens: 75000,
      estimated_cost: 7.5,
      request_count: 27,
    },
  ],
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function setupMocks(
  quotaResult: DataEnvelope<AiQuota> | Error = { data: baseQuota },
  usageResult: DataEnvelope<AiUsage> | Error = { data: baseUsage },
) {
  if (quotaResult instanceof Error) {
    vi.mocked(aiApi.getQuota).mockRejectedValue(quotaResult)
  } else {
    vi.mocked(aiApi.getQuota).mockResolvedValue(quotaResult)
  }
  if (usageResult instanceof Error) {
    vi.mocked(aiApi.getUsage).mockRejectedValue(usageResult)
  } else {
    vi.mocked(aiApi.getUsage).mockResolvedValue(usageResult)
  }
}

function mountPage() {
  const pinia = createPinia()
  setActivePinia(pinia)
  const router = createRouter({
    history: createWebHistory(),
    routes: [
      { path: '/', component: { template: '<div />' } },
      { path: '/app/ask', name: 'ask-voceive', component: { template: '<div />' } },
      { path: '/app/ai-usage', name: 'ai-usage', component: { template: '<div />' } },
    ],
  })
  return mount(AiUsagePage, {
    global: { plugins: [pinia, router] },
  })
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('AiUsagePage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  // -- Loading state --------------------------------------------------------

  it('shows loading skeleton initially', () => {
    setupMocks()
    const wrapper = mountPage()
    expect(wrapper.findAll('.animate-pulse').length).toBeGreaterThan(0)
  })

  it('hides skeleton after data loads', async () => {
    setupMocks()
    const wrapper = mountPage()
    await flushPromises()
    expect(wrapper.findAll('.animate-pulse').length).toBe(0)
  })

  // -- Loaded state ---------------------------------------------------------

  it('renders page header', async () => {
    setupMocks()
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('Organization AI Usage')
  })

  it('renders period label', async () => {
    setupMocks()
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('August 2026')
  })

  // -- Quota cards ----------------------------------------------------------

  it('renders tokens used', async () => {
    setupMocks()
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('Tokens Used')
    expect(wrapper.text()).toContain('125,000')
  })

  it('renders estimated cost', async () => {
    setupMocks()
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('Estimated Cost')
    expect(wrapper.text()).toContain('$12.50')
  })

  it('renders request count', async () => {
    setupMocks()
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('AI Requests')
    expect(wrapper.text()).toContain('42')
  })

  it('renders average latency', async () => {
    setupMocks()
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('1251ms avg latency')
  })

  // -- Progress bars --------------------------------------------------------

  it('renders token progress bar', async () => {
    setupMocks()
    const wrapper = mountPage()
    await flushPromises()

    const bars = wrapper.findAll('[role="progressbar"]')
    expect(bars.length).toBeGreaterThanOrEqual(1)

    const tokenBar = bars[0]
    expect(tokenBar.attributes('aria-valuenow')).toBe('25')
    expect(tokenBar.attributes('aria-valuemin')).toBe('0')
    expect(tokenBar.attributes('aria-valuemax')).toBe('100')
    expect(tokenBar.attributes('aria-label')).toContain('Token usage')
    expect(tokenBar.attributes('aria-label')).toContain('25.0%')
  })

  it('renders cost progress bar', async () => {
    setupMocks()
    const wrapper = mountPage()
    await flushPromises()

    const bars = wrapper.findAll('[role="progressbar"]')
    expect(bars.length).toBeGreaterThanOrEqual(2)

    const costBar = bars[1]
    expect(costBar.attributes('aria-valuenow')).toBe('25')
    expect(costBar.attributes('aria-label')).toContain('Cost usage')
  })

  it('renders token limit text', async () => {
    setupMocks()
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('25.0% used of 500,000 limit')
  })

  it('renders cost limit text', async () => {
    setupMocks()
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('25.0% used of $50.00 limit')
  })

  // -- Remaining quota summary ----------------------------------------------

  it('renders remaining quota summary', async () => {
    setupMocks()
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('Remaining Quota')
    expect(wrapper.text()).toContain('375,000')
    expect(wrapper.text()).toContain('tokens remaining')
    expect(wrapper.text()).toContain('$37.50')
    expect(wrapper.text()).toContain('cost remaining')
  })

  // -- Token breakdown ------------------------------------------------------

  it('renders token breakdown', async () => {
    setupMocks()
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('Token Breakdown')
    expect(wrapper.text()).toContain('Prompt tokens')
    expect(wrapper.text()).toContain('80,000')
    expect(wrapper.text()).toContain('Completion tokens')
    expect(wrapper.text()).toContain('45,000')
  })

  // -- By operation breakdown -----------------------------------------------

  it('renders operation breakdown', async () => {
    setupMocks()
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('By Operation')
    expect(wrapper.text()).toContain('chat')
    expect(wrapper.text()).toContain('embedding')
    expect(wrapper.text()).toContain('100,000')
    expect(wrapper.text()).toContain('30')
  })

  // -- By model breakdown ---------------------------------------------------

  it('renders model breakdown', async () => {
    setupMocks()
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('By Model')
    expect(wrapper.text()).toContain('gpt-4o')
    expect(wrapper.text()).toContain('text-embedding-3-small')
  })

  // -- Daily activity -------------------------------------------------------

  it('renders daily activity', async () => {
    setupMocks()
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('Daily Activity')
    expect(wrapper.text()).toContain('2026-08-15')
    expect(wrapper.text()).toContain('2026-08-16')
  })

  // -- No limits ------------------------------------------------------------

  it('shows "No token limit set" when limit is null', async () => {
    const noLimitQuota: AiQuota = {
      ...baseQuota,
      ai_monthly_token_limit: null,
      ai_monthly_cost_limit: null,
      current_month: {
        tokens_used: 125000,
        cost_used: 12.5,
        tokens_remaining: null,
        cost_remaining: null,
        token_percentage_used: null,
        cost_percentage_used: null,
      },
    }
    setupMocks({ data: noLimitQuota })
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('No token limit set')
    expect(wrapper.text()).toContain('No cost limit set')
  })

  it('does not render progress bars when limits are null', async () => {
    const noLimitQuota: AiQuota = {
      ...baseQuota,
      ai_monthly_token_limit: null,
      ai_monthly_cost_limit: null,
      current_month: {
        tokens_used: 125000,
        cost_used: 12.5,
        tokens_remaining: null,
        cost_remaining: null,
        token_percentage_used: null,
        cost_percentage_used: null,
      },
    }
    setupMocks({ data: noLimitQuota })
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.findAll('[role="progressbar"]').length).toBe(0)
  })

  it('does not render remaining quota summary when no limits', async () => {
    const noLimitQuota: AiQuota = {
      ...baseQuota,
      ai_monthly_token_limit: null,
      ai_monthly_cost_limit: null,
      current_month: {
        tokens_used: 125000,
        cost_used: 12.5,
        tokens_remaining: null,
        cost_remaining: null,
        token_percentage_used: null,
        cost_percentage_used: null,
      },
    }
    setupMocks({ data: noLimitQuota })
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).not.toContain('Remaining Quota')
  })

  // -- Warning states -------------------------------------------------------

  it('shows warning banner when usage is ≥90%', async () => {
    const criticalQuota: AiQuota = {
      ...baseQuota,
      current_month: {
        tokens_used: 475000,
        cost_used: 47.5,
        tokens_remaining: 25000,
        cost_remaining: 2.5,
        token_percentage_used: 95.0,
        cost_percentage_used: 95.0,
      },
    }
    setupMocks({ data: criticalQuota })
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('Approaching AI quota limit')
    expect(wrapper.text()).toContain('used over 90%')
  })

  it('shows exhausted banner when usage is ≥100%', async () => {
    const exhaustedQuota: AiQuota = {
      ...baseQuota,
      current_month: {
        tokens_used: 500000,
        cost_used: 50.0,
        tokens_remaining: 0,
        cost_remaining: 0,
        token_percentage_used: 100.0,
        cost_percentage_used: 100.0,
      },
    }
    setupMocks({ data: exhaustedQuota })
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('AI quota exhausted')
    expect(wrapper.text()).toContain('reached its AI usage limit')
  })

  it('does not show warning banner at normal usage', async () => {
    setupMocks()
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).not.toContain('Approaching AI quota limit')
    expect(wrapper.text()).not.toContain('AI quota exhausted')
  })

  it('exhausted banner has role="alert"', async () => {
    const exhaustedQuota: AiQuota = {
      ...baseQuota,
      current_month: {
        tokens_used: 500000,
        cost_used: 50.0,
        tokens_remaining: 0,
        cost_remaining: 0,
        token_percentage_used: 100.0,
        cost_percentage_used: 100.0,
      },
    }
    setupMocks({ data: exhaustedQuota })
    const wrapper = mountPage()
    await flushPromises()

    const alert = wrapper.find('[role="alert"]')
    expect(alert.exists()).toBe(true)
    expect(alert.text()).toContain('AI quota exhausted')
  })

  // -- Error state ----------------------------------------------------------

  it('shows error message on API failure', async () => {
    setupMocks(new ApiError({ status: 500, type: '/errors/internal', title: 'Internal', detail: 'Server error' }))
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('Unable to load AI usage')
    expect(wrapper.text()).toContain('Server error')
  })

  it('shows generic error for non-ApiError', async () => {
    setupMocks(new Error('Network error'))
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('Unable to load AI usage')
    expect(wrapper.text()).toContain('Something went wrong')
  })

  it('error state has role="alert"', async () => {
    setupMocks(new ApiError({ status: 500, type: '/errors/internal', title: 'Internal', detail: 'fail' }))
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.find('[role="alert"]').exists()).toBe(true)
  })

  it('retries on error button click', async () => {
    setupMocks(new ApiError({ status: 500, type: '/errors/internal', title: 'Internal', detail: 'fail' }))
    const wrapper = mountPage()
    await flushPromises()

    // Fix mocks to succeed on retry
    vi.mocked(aiApi.getQuota).mockResolvedValue({ data: baseQuota })
    vi.mocked(aiApi.getUsage).mockResolvedValue({ data: baseUsage })

    const retryBtn = wrapper.findAll('button').find(b => b.text().includes('Try again'))
    expect(retryBtn).toBeDefined()
    await retryBtn!.trigger('click')
    await flushPromises()

    expect(wrapper.text()).toContain('Organization AI Usage')
    expect(wrapper.text()).not.toContain('Unable to load AI usage')
  })

  // -- Empty state ----------------------------------------------------------

  it('shows empty state when request_count is 0', async () => {
    const emptyUsage: AiUsage = {
      ...baseUsage,
      request_count: 0,
      prompt_tokens: 0,
      completion_tokens: 0,
      average_latency_ms: 0,
      tokens: { used: 0, limit: 500000, remaining: 500000, percentage_used: 0 },
      cost: { used: 0, limit: 50, remaining: 50, percentage_used: 0 },
      by_operation: [],
      by_model: [],
      by_user: [],
      by_day: [],
    }
    setupMocks({ data: baseQuota }, { data: emptyUsage })
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('No AI usage yet')
    expect(wrapper.text()).toContain('Start using Ask Voceive')
  })

  it('empty state links to Ask Voceive', async () => {
    const emptyUsage: AiUsage = {
      ...baseUsage,
      request_count: 0,
      by_operation: [],
      by_model: [],
      by_user: [],
      by_day: [],
    }
    setupMocks({ data: baseQuota }, { data: emptyUsage })
    const wrapper = mountPage()
    await flushPromises()

    const link = wrapper.find('a[href="/app/ask"]')
    expect(link.exists()).toBe(true)
    expect(link.text()).toContain('Try Ask Voceive')
  })

  // -- Data correctness -----------------------------------------------------

  it('calls getQuota and getUsage on mount', async () => {
    setupMocks()
    mountPage()
    await flushPromises()

    expect(aiApi.getQuota).toHaveBeenCalledTimes(1)
    expect(aiApi.getUsage).toHaveBeenCalledTimes(1)
  })

  it('uses backend-provided values not defaults', async () => {
    const customQuota: AiQuota = {
      ...baseQuota,
      ai_monthly_token_limit: 1000000,
      current_month: {
        tokens_used: 999000,
        cost_used: 99.0,
        tokens_remaining: 1000,
        cost_remaining: 1.0,
        token_percentage_used: 99.9,
        cost_percentage_used: 99.0,
      },
    }
    const customUsage: AiUsage = {
      ...baseUsage,
      tokens: { used: 999000, limit: 1000000, remaining: 1000, percentage_used: 99.9 },
      cost: { used: 99.0, limit: 100.0, remaining: 1.0, percentage_used: 99.0 },
      request_count: 500,
    }
    setupMocks({ data: customQuota }, { data: customUsage })
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('999,000')
    expect(wrapper.text()).toContain('$99.00')
    expect(wrapper.text()).toContain('500')
  })

  // -- Responsive behavior --------------------------------------------------

  it('renders all three summary cards', async () => {
    setupMocks()
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('Tokens Used')
    expect(wrapper.text()).toContain('Estimated Cost')
    expect(wrapper.text()).toContain('AI Requests')
  })

  // -- Empty breakdowns are hidden ------------------------------------------

  it('hides operation breakdown when empty', async () => {
    const noOpUsage: AiUsage = { ...baseUsage, by_operation: [] }
    setupMocks({ data: baseQuota }, { data: noOpUsage })
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).not.toContain('By Operation')
  })

  it('hides model breakdown when empty', async () => {
    const noModelUsage: AiUsage = { ...baseUsage, by_model: [] }
    setupMocks({ data: baseQuota }, { data: noModelUsage })
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).not.toContain('By Model')
  })

  it('hides daily activity when empty', async () => {
    const noDayUsage: AiUsage = { ...baseUsage, by_day: [] }
    setupMocks({ data: baseQuota }, { data: noDayUsage })
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).not.toContain('Daily Activity')
  })

  // -- Period label handling ------------------------------------------------

  it('formats YYYY-MM period as human-readable month', async () => {
    const janUsage: AiUsage = { ...baseUsage, period: '2026-01' }
    setupMocks({ data: baseQuota }, { data: janUsage })
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('January 2026')
  })

  it('shows raw period string for non-standard format', async () => {
    const rangeUsage: AiUsage = { ...baseUsage, period: '2026-06-01..2026-08-31' }
    setupMocks({ data: baseQuota }, { data: rangeUsage })
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('2026-06-01..2026-08-31')
  })

  // -- Warning state at 75% ------------------------------------------------

  it('does not show warning banner at 75% usage', async () => {
    const quota75: AiQuota = {
      ...baseQuota,
      current_month: {
        ...baseQuota.current_month,
        token_percentage_used: 75.0,
        cost_percentage_used: 75.0,
      },
    }
    setupMocks({ data: quota75 })
    const wrapper = mountPage()
    await flushPromises()

    // 75% is "warning" state but the banner only shows at "critical" (>=90%)
    expect(wrapper.text()).not.toContain('Approaching AI quota limit')
    expect(wrapper.text()).not.toContain('AI quota exhausted')
  })
})
