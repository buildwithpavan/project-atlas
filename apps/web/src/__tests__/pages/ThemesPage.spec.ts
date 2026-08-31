import { describe, it, expect, beforeEach, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { createRouter, createWebHistory } from 'vue-router'
import ThemesPage from '@/pages/ThemesPage.vue'
import * as themesApi from '@/api/themes'
import type { Theme, ListEnvelope } from '@/api/types'

vi.mock('@/api/themes')
vi.mock('@/api/auth', () => ({
  login: vi.fn(),
  register: vi.fn(),
  logout: vi.fn(),
  refresh: vi.fn(),
}))

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const sampleThemes: Theme[] = [
  {
    id: '1',
    title: 'Billing Issues',
    description: 'Multiple customers reporting billing problems',
    status: 'active',
    severity: 'high',
    ticket_count: 5,
    evidence_summary: '5 tickets mention billing',
    recommended_action: 'Investigate billing system',
    first_seen_at: '2026-08-01T00:00:00Z',
    last_seen_at: '2026-08-15T00:00:00Z',
    created_at: '2026-08-01T00:00:00Z',
  },
  {
    id: '2',
    title: 'Login Failures',
    description: 'Users unable to log in',
    status: 'active',
    severity: 'critical',
    ticket_count: 8,
    evidence_summary: '8 tickets about login',
    recommended_action: 'Fix auth flow',
    first_seen_at: '2026-08-05T00:00:00Z',
    last_seen_at: '2026-08-16T00:00:00Z',
    created_at: '2026-08-05T00:00:00Z',
  },
]

const emptyResponse: ListEnvelope<Theme> = { data: [], meta: { total: 0 } }
const loadedResponse: ListEnvelope<Theme> = {
  data: sampleThemes,
  meta: { total: 2 },
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function setupMock(
  response: ListEnvelope<Theme> | Error = loadedResponse,
  detectResponse: Error | null = null,
) {
  if (response instanceof Error) {
    vi.mocked(themesApi.list).mockRejectedValue(response)
  } else {
    vi.mocked(themesApi.list).mockResolvedValue(response)
  }
  if (detectResponse instanceof Error) {
    vi.mocked(themesApi.detect).mockRejectedValue(detectResponse)
  } else {
    vi.mocked(themesApi.detect).mockResolvedValue({
      data: { message: 'Theme detection started' },
    })
  }
}

function makeRouter() {
  return createRouter({
    history: createWebHistory(),
    routes: [
      { path: '/', component: { template: '<div />' } },
      { path: '/app/themes', name: 'themes', component: ThemesPage },
      { path: '/app/themes/:id', name: 'theme-detail', component: { template: '<div />' } },
    ],
  })
}

function mountPage() {
  const pinia = createPinia()
  setActivePinia(pinia)
  const router = makeRouter()
  return mount(ThemesPage, {
    global: { plugins: [pinia, router] },
  })
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('ThemesPage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  // -- Loading state --------------------------------------------------------

  it('shows loading skeleton initially', () => {
    setupMock()
    const wrapper = mountPage()
    expect(wrapper.findAll('.animate-pulse').length).toBeGreaterThan(0)
  })

  it('hides skeleton after data loads', async () => {
    setupMock()
    const wrapper = mountPage()
    await flushPromises()
    expect(wrapper.findAll('.animate-pulse').length).toBe(0)
  })

  // -- Rendering ------------------------------------------------------------

  it('renders page header', async () => {
    setupMock()
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.find('h1').text()).toBe('Themes')
    expect(wrapper.text()).toContain('Recurring patterns')
  })

  it('renders theme cards when data is loaded', async () => {
    setupMock()
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('Billing Issues')
    expect(wrapper.text()).toContain('Login Failures')
  })

  it('shows severity badges', async () => {
    setupMock()
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('high')
    expect(wrapper.text()).toContain('critical')
  })

  it('shows ticket counts', async () => {
    setupMock()
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('5 tickets')
    expect(wrapper.text()).toContain('8 tickets')
  })

  it('shows recommended actions', async () => {
    setupMock()
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('Recommendation:')
    expect(wrapper.text()).toContain('Investigate billing system')
    expect(wrapper.text()).toContain('Fix auth flow')
  })

  it('shows date information', async () => {
    setupMock()
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('First:')
    expect(wrapper.text()).toContain('Last:')
  })

  // -- Sorting --------------------------------------------------------------

  it('sorts themes by severity (critical first)', async () => {
    setupMock()
    const wrapper = mountPage()
    await flushPromises()

    const titles = wrapper.findAll('h3').map((h) => h.text())
    expect(titles[0]).toBe('Login Failures')
    expect(titles[1]).toBe('Billing Issues')
  })

  // -- Filters --------------------------------------------------------------

  it('has status and severity filter selects', async () => {
    setupMock()
    const wrapper = mountPage()
    await flushPromises()

    const selects = wrapper.findAll('select')
    expect(selects.length).toBe(2)
  })

  it('filter selects have accessible labels', async () => {
    setupMock()
    const wrapper = mountPage()
    await flushPromises()

    const statusSelect = wrapper.find('#theme-status-filter')
    expect(statusSelect.exists()).toBe(true)
    expect(statusSelect.attributes('aria-label')).toBe('Filter by status')

    const severitySelect = wrapper.find('#theme-severity-filter')
    expect(severitySelect.exists()).toBe(true)
    expect(severitySelect.attributes('aria-label')).toBe('Filter by severity')
  })

  it('filter selects have sr-only label elements', async () => {
    setupMock()
    const wrapper = mountPage()
    await flushPromises()

    const labels = wrapper.findAll('label.sr-only')
    expect(labels.length).toBe(2)
  })

  it('refetches when status filter changes', async () => {
    setupMock()
    const wrapper = mountPage()
    await flushPromises()

    vi.mocked(themesApi.list).mockClear()
    const statusSelect = wrapper.find('#theme-status-filter')
    await statusSelect.setValue('resolved')

    expect(themesApi.list).toHaveBeenCalledWith(
      expect.objectContaining({ status: 'resolved' }),
    )
  })

  it('refetches when severity filter changes', async () => {
    setupMock()
    const wrapper = mountPage()
    await flushPromises()

    vi.mocked(themesApi.list).mockClear()
    const severitySelect = wrapper.find('#theme-severity-filter')
    await severitySelect.setValue('critical')

    expect(themesApi.list).toHaveBeenCalledWith(
      expect.objectContaining({ severity: 'critical' }),
    )
  })

  // -- Navigation -----------------------------------------------------------

  it('theme cards have accessible role and keyboard support', async () => {
    setupMock()
    const wrapper = mountPage()
    await flushPromises()

    const themeCards = wrapper.findAll('[role="link"]')
    expect(themeCards.length).toBe(2)
    expect(themeCards[0].attributes('tabindex')).toBe('0')
  })

  // -- Empty state ----------------------------------------------------------

  it('shows empty state when no themes', async () => {
    setupMock(emptyResponse)
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('No themes detected')
    expect(wrapper.text()).toContain('Import customer tickets')
  })

  it('empty state has a detect themes button', async () => {
    setupMock(emptyResponse)
    const wrapper = mountPage()
    await flushPromises()

    const detectBtn = wrapper.findAll('button').find(b => b.text().includes('Detect Themes'))
    expect(detectBtn).toBeDefined()
  })

  // -- Error state ----------------------------------------------------------

  it('shows error state on API failure', async () => {
    setupMock(new Error('Network error'))
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('Unable to load themes')
    expect(wrapper.text()).toContain('Failed to load themes')
  })

  it('error state has role="alert"', async () => {
    setupMock(new Error('fail'))
    const wrapper = mountPage()
    await flushPromises()

    expect(wrapper.find('[role="alert"]').exists()).toBe(true)
  })

  it('retries on error retry button click', async () => {
    setupMock(new Error('fail'))
    const wrapper = mountPage()
    await flushPromises()

    vi.mocked(themesApi.list).mockResolvedValue(loadedResponse)

    const retryBtn = wrapper.findAll('button').find(b => b.text().includes('Try again'))
    expect(retryBtn).toBeDefined()
    await retryBtn!.trigger('click')
    await flushPromises()

    expect(wrapper.text()).toContain('Billing Issues')
    expect(wrapper.text()).not.toContain('Unable to load themes')
  })

  // -- Detect themes --------------------------------------------------------

  it('has a Detect Themes button', async () => {
    setupMock()
    const wrapper = mountPage()
    await flushPromises()

    const detectBtn = wrapper.findAll('button').find(b => b.text().includes('Detect Themes'))
    expect(detectBtn).toBeDefined()
  })

  it('calls detect API when button clicked', async () => {
    setupMock()
    const wrapper = mountPage()
    await flushPromises()

    const detectBtn = wrapper.findAll('button').find(b => b.text().includes('Detect Themes'))
    await detectBtn!.trigger('click')
    expect(themesApi.detect).toHaveBeenCalledTimes(1)
  })

  it('shows detection error with retry', async () => {
    setupMock(loadedResponse, new Error('Detection failed'))
    const wrapper = mountPage()
    await flushPromises()

    const detectBtn = wrapper.findAll('button').find(b => b.text().includes('Detect Themes'))
    await detectBtn!.trigger('click')
    await flushPromises()

    expect(wrapper.text()).toContain('Failed to start theme detection')
    const retryBtn = wrapper.findAll('button').find(b => b.text() === 'Retry')
    expect(retryBtn).toBeDefined()
  })

  // -- API call on mount ----------------------------------------------------

  it('calls list API on mount with default status filter', async () => {
    setupMock()
    mountPage()
    await flushPromises()

    expect(themesApi.list).toHaveBeenCalledWith({ status: 'active', severity: undefined })
  })
})
