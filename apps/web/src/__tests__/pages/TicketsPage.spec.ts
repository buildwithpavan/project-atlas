import { describe, it, expect, beforeEach, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { createRouter, createWebHistory } from 'vue-router'
import TicketsPage from '@/pages/TicketsPage.vue'
import * as ticketsApi from '@/api/tickets'
import { ApiError } from '@/api/errors'
import type { Ticket, PaginationMeta, PaginatedEnvelope } from '@/api/types'

vi.mock('@/api/tickets')
vi.mock('@/api/auth', () => ({
  login: vi.fn(),
  register: vi.fn(),
  logout: vi.fn(),
  refresh: vi.fn(),
}))

const sampleTickets: Ticket[] = [
  {
    id: '1',
    subject: 'Cannot log in after update',
    status: 'open',
    priority: 'high',
    category: 'login',
    customer_name: 'Jane Doe',
    customer_email: 'jane@example.com',
    created_at: '2026-08-01T10:00:00Z',
    updated_at: '2026-08-01T10:00:00Z',
  },
  {
    id: '2',
    subject: 'Billing page slow',
    status: 'closed',
    priority: 'medium',
    category: 'billing',
    customer_name: 'John Smith',
    customer_email: 'john@example.com',
    created_at: '2026-07-30T08:00:00Z',
    updated_at: '2026-07-31T12:00:00Z',
  },
]

const sampleMeta: PaginationMeta = {
  page: 1,
  per_page: 20,
  total: 2,
  total_pages: 1,
}

function makeResponse(
  data: Ticket[] = sampleTickets,
  meta: PaginationMeta = sampleMeta,
): PaginatedEnvelope<Ticket> {
  return { data, meta }
}

function makeRouter() {
  return createRouter({
    history: createWebHistory(),
    routes: [
      { path: '/app/tickets', name: 'tickets', component: TicketsPage },
      { path: '/app/tickets/:id', name: 'ticket-detail', component: { template: '<div />' } },
      { path: '/app/import', name: 'import', component: { template: '<div />' } },
    ],
  })
}

async function mountPage(query: Record<string, string> = {}) {
  const pinia = createPinia()
  setActivePinia(pinia)
  const router = makeRouter()
  await router.push({ path: '/app/tickets', query })
  await router.isReady()

  return mount(TicketsPage, {
    global: { plugins: [pinia, router] },
  })
}

describe('TicketsPage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.useFakeTimers()
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  // -- Loading state --------------------------------------------------------

  it('shows loading skeleton initially', async () => {
    vi.mocked(ticketsApi.list).mockReturnValue(new Promise(() => {})) // never resolves
    const wrapper = await mountPage()
    expect(wrapper.findAll('.animate-pulse').length).toBeGreaterThan(0)
  })

  // -- Successful rendering -------------------------------------------------

  it('renders ticket rows after loading', async () => {
    vi.mocked(ticketsApi.list).mockResolvedValue(makeResponse())
    const wrapper = await mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('Cannot log in after update')
    expect(wrapper.text()).toContain('Billing page slow')
  })

  it('renders page header', async () => {
    vi.mocked(ticketsApi.list).mockResolvedValue(makeResponse())
    const wrapper = await mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('Tickets')
    expect(wrapper.text()).toContain('Explore the customer conversations')
  })

  it('renders customer names', async () => {
    vi.mocked(ticketsApi.list).mockResolvedValue(makeResponse())
    const wrapper = await mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('Jane Doe')
    expect(wrapper.text()).toContain('John Smith')
  })

  it('renders status badges', async () => {
    vi.mocked(ticketsApi.list).mockResolvedValue(makeResponse())
    const wrapper = await mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('open')
    expect(wrapper.text()).toContain('closed')
  })

  it('renders priority badges', async () => {
    vi.mocked(ticketsApi.list).mockResolvedValue(makeResponse())
    const wrapper = await mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('high')
    expect(wrapper.text()).toContain('medium')
  })

  // -- Search ---------------------------------------------------------------

  it('debounces search input', async () => {
    vi.mocked(ticketsApi.list).mockResolvedValue(makeResponse())
    const wrapper = await mountPage()
    await flushPromises()

    vi.mocked(ticketsApi.list).mockClear()
    vi.mocked(ticketsApi.list).mockResolvedValue(makeResponse([]))

    // Type into search
    const searchInput = wrapper.find('input[type="search"]')
    await searchInput.setValue('login')

    // Not called yet (debounced)
    expect(ticketsApi.list).not.toHaveBeenCalled()

    // Advance past debounce
    vi.advanceTimersByTime(350)
    await flushPromises()

    expect(ticketsApi.list).toHaveBeenCalledWith(
      expect.objectContaining({ search: 'login' }),
    )
  })

  // -- Status filter --------------------------------------------------------

  it('filters by status', async () => {
    vi.mocked(ticketsApi.list).mockResolvedValue(makeResponse())
    const wrapper = await mountPage()
    await flushPromises()

    vi.mocked(ticketsApi.list).mockClear()
    vi.mocked(ticketsApi.list).mockResolvedValue(makeResponse([sampleTickets[0]]))

    const statusSelect = wrapper.find('select[aria-label="Filter by status"]')
    await statusSelect.setValue('open')
    await flushPromises()

    expect(ticketsApi.list).toHaveBeenCalledWith(
      expect.objectContaining({ status: 'open' }),
    )
  })

  // -- Priority filter ------------------------------------------------------

  it('filters by priority', async () => {
    vi.mocked(ticketsApi.list).mockResolvedValue(makeResponse())
    const wrapper = await mountPage()
    await flushPromises()

    vi.mocked(ticketsApi.list).mockClear()
    vi.mocked(ticketsApi.list).mockResolvedValue(makeResponse([sampleTickets[0]]))

    const prioritySelect = wrapper.find('select[aria-label="Filter by priority"]')
    await prioritySelect.setValue('high')
    await flushPromises()

    expect(ticketsApi.list).toHaveBeenCalledWith(
      expect.objectContaining({ priority: 'high' }),
    )
  })

  // -- Clear filters --------------------------------------------------------

  it('clear filters resets and reloads', async () => {
    vi.mocked(ticketsApi.list).mockResolvedValue(makeResponse())
    const wrapper = await mountPage({ status: 'open' })
    await flushPromises()

    vi.mocked(ticketsApi.list).mockClear()
    vi.mocked(ticketsApi.list).mockResolvedValue(makeResponse())

    // Clear button should be visible
    const clearBtn = wrapper.findAll('button').find(b => b.text().includes('Clear filters'))
    expect(clearBtn).toBeTruthy()
    await clearBtn!.trigger('click')
    await flushPromises()

    expect(ticketsApi.list).toHaveBeenCalledWith(
      expect.objectContaining({
        search: undefined,
        status: undefined,
        priority: undefined,
        page: 1,
      }),
    )
  })

  // -- Pagination -----------------------------------------------------------

  it('renders pagination for multi-page results', async () => {
    vi.mocked(ticketsApi.list).mockResolvedValue(
      makeResponse(sampleTickets, { page: 1, per_page: 20, total: 50, total_pages: 3 }),
    )
    const wrapper = await mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('Page 1 of 3')
    expect(wrapper.text()).toContain('Next')
  })

  it('next page triggers API call', async () => {
    vi.mocked(ticketsApi.list).mockResolvedValue(
      makeResponse(sampleTickets, { page: 1, per_page: 20, total: 50, total_pages: 3 }),
    )
    const wrapper = await mountPage()
    await flushPromises()

    vi.mocked(ticketsApi.list).mockClear()
    vi.mocked(ticketsApi.list).mockResolvedValue(
      makeResponse(sampleTickets, { page: 2, per_page: 20, total: 50, total_pages: 3 }),
    )

    const nextBtn = wrapper.findAll('button').find(b => b.text().includes('Next'))
    await nextBtn!.trigger('click')
    await flushPromises()

    expect(ticketsApi.list).toHaveBeenCalledWith(
      expect.objectContaining({ page: 2 }),
    )
  })

  // -- Empty states ---------------------------------------------------------

  it('shows organization empty state when no tickets and no filters', async () => {
    vi.mocked(ticketsApi.list).mockResolvedValue(makeResponse([], { page: 1, per_page: 20, total: 0, total_pages: 0 }))
    const wrapper = await mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('No tickets yet')
    expect(wrapper.text()).toContain('Import customer tickets')
    const importLink = wrapper.find('a[href="/app/import"]')
    expect(importLink.exists()).toBe(true)
    expect(importLink.text()).toContain('Import Data')
  })

  it('shows filtered empty state when no results with active filter', async () => {
    vi.mocked(ticketsApi.list).mockResolvedValue(makeResponse([], { page: 1, per_page: 20, total: 0, total_pages: 0 }))
    const wrapper = await mountPage({ status: 'open' })
    await flushPromises()

    expect(wrapper.text()).toContain('No tickets match your filters')
  })

  // -- Error state ----------------------------------------------------------

  it('shows error on API failure', async () => {
    vi.mocked(ticketsApi.list).mockRejectedValue(
      new ApiError({
        type: '/errors/internal',
        title: 'Server Error',
        status: 500,
        detail: 'Database unavailable',
      }),
    )
    const wrapper = await mountPage()
    await flushPromises()

    expect(wrapper.text()).toContain('Unable to load tickets')
    expect(wrapper.text()).toContain('Database unavailable')
  })

  it('retry button on error calls API again', async () => {
    vi.mocked(ticketsApi.list).mockRejectedValue(new Error('fail'))
    const wrapper = await mountPage()
    await flushPromises()

    vi.mocked(ticketsApi.list).mockClear()
    vi.mocked(ticketsApi.list).mockResolvedValue(makeResponse())

    const retryBtn = wrapper.findAll('button').find(b => b.text().includes('Try again'))
    await retryBtn!.trigger('click')
    await flushPromises()

    expect(ticketsApi.list).toHaveBeenCalled()
    expect(wrapper.text()).toContain('Cannot log in after update')
  })

  // -- URL query sync -------------------------------------------------------

  it('reads initial filters from URL query', async () => {
    vi.mocked(ticketsApi.list).mockResolvedValue(makeResponse())
    await mountPage({ search: 'billing', status: 'closed', page: '2' })
    await flushPromises()

    expect(ticketsApi.list).toHaveBeenCalledWith(
      expect.objectContaining({
        search: 'billing',
        status: 'closed',
        page: 2,
      }),
    )
  })

  // -- Row click navigation -------------------------------------------------

  it('clicking a ticket row navigates to detail', async () => {
    vi.mocked(ticketsApi.list).mockResolvedValue(makeResponse())
    const pinia = createPinia()
    setActivePinia(pinia)
    const router = makeRouter()
    await router.push('/app/tickets')
    await router.isReady()
    const pushSpy = vi.spyOn(router, 'push')

    const wrapper = mount(TicketsPage, {
      global: { plugins: [pinia, router] },
    })
    await flushPromises()

    // Click first row (desktop table)
    const row = wrapper.find('tr[role="link"]')
    await row.trigger('click')

    expect(pushSpy).toHaveBeenCalledWith({
      name: 'ticket-detail',
      params: { id: '1' },
    })
  })
})
