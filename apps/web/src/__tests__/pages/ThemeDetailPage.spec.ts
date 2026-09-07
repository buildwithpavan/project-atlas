import { describe, it, expect, beforeEach, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { createRouter, createWebHistory } from 'vue-router'
import ThemeDetailPage from '@/pages/ThemeDetailPage.vue'
import * as themesApi from '@/api/themes'
import type { ThemeDetail, DataEnvelope } from '@/api/types'

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

const sampleTheme: ThemeDetail = {
  id: 'theme-1',
  title: 'Login failures across mobile',
  description: 'Multiple customers reporting login issues on mobile devices.',
  status: 'active',
  severity: 'high',
  ticket_count: 2,
  evidence_summary: 'Session tokens expire prematurely on mobile clients.',
  recommended_action: 'Investigate mobile session handling.',
  first_seen_at: '2026-08-01T00:00:00Z',
  last_seen_at: '2026-08-15T00:00:00Z',
  created_at: '2026-08-01T00:00:00Z',
  tickets: [
    {
      id: 'ticket-1',
      subject: 'Cannot log in on iPhone',
      customer_name: 'Alice Smith',
      priority: 'high',
      status: 'open',
      relevance_score: 0.95,
      evidence_text: 'User reports immediate session expiry after login.',
      created_at: '2026-08-02T00:00:00Z',
    },
    {
      id: 'ticket-2',
      subject: 'Android app kicks me out',
      customer_name: 'Bob Jones',
      priority: 'medium',
      status: 'open',
      relevance_score: 0.82,
      evidence_text: null,
      created_at: '2026-08-05T00:00:00Z',
    },
  ],
}

const themeNoTickets: ThemeDetail = {
  ...sampleTheme,
  id: 'theme-empty',
  ticket_count: 0,
  tickets: [],
  evidence_summary: null,
  recommended_action: null,
}

const successResponse: DataEnvelope<ThemeDetail> = { data: sampleTheme }
const emptyTicketsResponse: DataEnvelope<ThemeDetail> = { data: themeNoTickets }

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function setupMock(response: DataEnvelope<ThemeDetail> | Error = successResponse) {
  if (response instanceof Error) {
    vi.mocked(themesApi.getById).mockRejectedValue(response)
  } else {
    vi.mocked(themesApi.getById).mockResolvedValue(response)
  }
}

function makeRouter() {
  return createRouter({
    history: createWebHistory(),
    routes: [
      { path: '/', component: { template: '<div />' } },
      { path: '/app/themes', name: 'themes', component: { template: '<div />' } },
      { path: '/app/themes/:id', name: 'theme-detail', component: ThemeDetailPage },
      { path: '/app/tickets/:id', name: 'ticket-detail', component: { template: '<div />' } },
    ],
  })
}

async function mountPage(response?: DataEnvelope<ThemeDetail> | Error) {
  setupMock(response)
  const pinia = createPinia()
  setActivePinia(pinia)
  const router = makeRouter()
  await router.push('/app/themes/theme-1')
  await router.isReady()

  const wrapper = mount(ThemeDetailPage, {
    global: { plugins: [pinia, router] },
  })
  return wrapper
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('ThemeDetailPage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  // -- Loading state --------------------------------------------------------

  it('shows loading skeleton initially', async () => {
    setupMock()
    const wrapper = await mountPage()
    // Before flushPromises, skeleton should be visible
    expect(wrapper.findAll('.animate-pulse').length).toBeGreaterThan(0)
  })

  it('hides skeleton after data loads', async () => {
    const wrapper = await mountPage()
    await flushPromises()
    expect(wrapper.findAll('.animate-pulse').length).toBe(0)
  })

  // -- Back navigation ------------------------------------------------------

  it('renders back button', async () => {
    const wrapper = await mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('Back to Themes')
  })

  // -- Theme rendering ------------------------------------------------------

  it('renders theme title', async () => {
    const wrapper = await mountPage()
    await flushPromises()

    expect(wrapper.find('h1').text()).toBe('Login failures across mobile')
  })

  it('renders theme description', async () => {
    const wrapper = await mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('Multiple customers reporting login issues')
  })

  it('renders severity badge', async () => {
    const wrapper = await mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('high')
  })

  it('renders status badge', async () => {
    const wrapper = await mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('active')
  })

  it('renders ticket count', async () => {
    const wrapper = await mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('2 tickets')
  })

  it('renders dates', async () => {
    const wrapper = await mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('First seen:')
    expect(wrapper.text()).toContain('Last seen:')
  })

  // -- Evidence & recommendation --------------------------------------------

  it('renders evidence summary', async () => {
    const wrapper = await mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('Evidence Summary')
    expect(wrapper.text()).toContain('Session tokens expire prematurely')
  })

  it('renders recommended action', async () => {
    const wrapper = await mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('Recommended Action')
    expect(wrapper.text()).toContain('Investigate mobile session handling')
  })

  it('hides evidence summary when null', async () => {
    const wrapper = await mountPage(emptyTicketsResponse)
    await flushPromises()

    expect(wrapper.text()).not.toContain('Evidence Summary')
  })

  it('hides recommended action when null', async () => {
    const wrapper = await mountPage(emptyTicketsResponse)
    await flushPromises()

    expect(wrapper.text()).not.toContain('Recommended Action')
  })

  // -- Supporting tickets ---------------------------------------------------

  it('renders supporting tickets heading', async () => {
    const wrapper = await mountPage()
    await flushPromises()

    expect(wrapper.find('h2').text()).toBe('Supporting Tickets')
  })

  it('renders ticket subjects', async () => {
    const wrapper = await mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('Cannot log in on iPhone')
    expect(wrapper.text()).toContain('Android app kicks me out')
  })

  it('renders customer names', async () => {
    const wrapper = await mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('Alice Smith')
    expect(wrapper.text()).toContain('Bob Jones')
  })

  it('renders relevance scores', async () => {
    const wrapper = await mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('95% relevant')
    expect(wrapper.text()).toContain('82% relevant')
  })

  it('renders evidence text when present', async () => {
    const wrapper = await mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('User reports immediate session expiry')
  })

  it('renders ticket priority', async () => {
    const wrapper = await mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('high')
    expect(wrapper.text()).toContain('medium')
  })

  it('ticket cards are keyboard accessible', async () => {
    const wrapper = await mountPage()
    await flushPromises()

    const ticketCards = wrapper.findAll('[role="link"]')
    expect(ticketCards.length).toBe(2)
    expect(ticketCards[0].attributes('tabindex')).toBe('0')
  })

  // -- Empty tickets --------------------------------------------------------

  it('shows empty state when no tickets', async () => {
    const wrapper = await mountPage(emptyTicketsResponse)
    await flushPromises()

    expect(wrapper.text()).toContain('No supporting tickets found')
  })

  // -- Error state ----------------------------------------------------------

  it('shows error state on API failure', async () => {
    const wrapper = await mountPage(new Error('Not found'))
    await flushPromises()

    expect(wrapper.text()).toContain('Failed to load theme')
  })

  it('error state has role="alert"', async () => {
    const wrapper = await mountPage(new Error('fail'))
    await flushPromises()

    expect(wrapper.find('[role="alert"]').exists()).toBe(true)
  })

  it('retries on error retry button click', async () => {
    const wrapper = await mountPage(new Error('fail'))
    await flushPromises()

    vi.mocked(themesApi.getById).mockResolvedValue(successResponse)

    const retryBtn = wrapper.findAll('button').find(b => b.text().includes('Try again'))
    expect(retryBtn).toBeDefined()
    await retryBtn!.trigger('click')
    await flushPromises()

    expect(wrapper.text()).toContain('Login failures across mobile')
    expect(wrapper.text()).not.toContain('Failed to load theme')
  })

  // -- API call on mount ----------------------------------------------------

  it('calls getById API on mount with route param', async () => {
    await mountPage()
    await flushPromises()

    expect(themesApi.getById).toHaveBeenCalledWith('theme-1')
  })

  // -- Singular ticket count ------------------------------------------------

  it('shows singular "ticket" for count of 1', async () => {
    const singleTicketTheme: ThemeDetail = {
      ...sampleTheme,
      ticket_count: 1,
      tickets: [sampleTheme.tickets[0]],
    }
    const wrapper = await mountPage({ data: singleTicketTheme })
    await flushPromises()

    expect(wrapper.text()).toContain('1 ticket')
    expect(wrapper.text()).not.toContain('1 tickets')
  })
})
