import { describe, it, expect, beforeEach, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { createRouter, createWebHistory } from 'vue-router'
import TicketDetailPage from '@/pages/TicketDetailPage.vue'
import * as ticketsApi from '@/api/tickets'
import { ApiError } from '@/api/errors'
import type { TicketDetail, DataEnvelope } from '@/api/types'

vi.mock('@/api/tickets')
vi.mock('@/api/auth', () => ({
  login: vi.fn(),
  register: vi.fn(),
  logout: vi.fn(),
  refresh: vi.fn(),
}))

const completedTicket: TicketDetail = {
  id: '1',
  subject: 'Cannot log in after update',
  description: 'I updated the app and now I cannot log in. The login button does nothing when clicked.',
  status: 'open',
  priority: 'high',
  category: 'login',
  customer_name: 'Jane Doe',
  customer_email: 'jane@example.com',
  created_at: '2026-08-01T10:00:00Z',
  updated_at: '2026-08-01T10:00:00Z',
  upload_id: 'u1',
  ai_analysis: {
    id: 'a1',
    status: 'completed',
    sentiment: 'negative',
    summary: 'Customer unable to log in after recent application update.',
    category: 'login',
    confidence: 0.92,
    feature_request: false,
    bug_report: true,
    knowledge_gap: false,
    processed_at: '2026-08-01T10:05:00Z',
  },
}

function makeRouter() {
  return createRouter({
    history: createWebHistory(),
    routes: [
      { path: '/app/tickets', name: 'tickets', component: { template: '<div />' } },
      { path: '/app/tickets/:id', name: 'ticket-detail', component: TicketDetailPage },
    ],
  })
}

async function mountDetail(
  id = '1',
  response?: DataEnvelope<TicketDetail> | Error,
) {
  const pinia = createPinia()
  setActivePinia(pinia)
  const router = makeRouter()

  if (response instanceof Error) {
    vi.mocked(ticketsApi.getById).mockRejectedValue(response)
  } else {
    vi.mocked(ticketsApi.getById).mockResolvedValue(
      response ?? { data: completedTicket },
    )
  }

  await router.push(`/app/tickets/${id}`)
  await router.isReady()

  const wrapper = mount(TicketDetailPage, {
    global: { plugins: [pinia, router] },
  })
  await flushPromises()
  return { wrapper, router }
}

describe('TicketDetailPage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  // -- Loading state --------------------------------------------------------

  it('shows loading skeleton', async () => {
    vi.mocked(ticketsApi.getById).mockReturnValue(new Promise(() => {}))
    const pinia = createPinia()
    setActivePinia(pinia)
    const router = makeRouter()
    await router.push('/app/tickets/1')
    await router.isReady()

    const wrapper = mount(TicketDetailPage, {
      global: { plugins: [pinia, router] },
    })
    expect(wrapper.findAll('.animate-pulse').length).toBeGreaterThan(0)
  })

  // -- Successful rendering -------------------------------------------------

  it('renders ticket subject', async () => {
    const { wrapper } = await mountDetail()
    expect(wrapper.text()).toContain('Cannot log in after update')
  })

  it('renders customer information', async () => {
    const { wrapper } = await mountDetail()
    expect(wrapper.text()).toContain('Jane Doe')
    expect(wrapper.text()).toContain('jane@example.com')
  })

  it('renders status and priority badges', async () => {
    const { wrapper } = await mountDetail()
    expect(wrapper.text()).toContain('open')
    expect(wrapper.text()).toContain('high')
  })

  it('renders ticket description', async () => {
    const { wrapper } = await mountDetail()
    expect(wrapper.text()).toContain('login button does nothing')
  })

  it('renders category badge', async () => {
    const { wrapper } = await mountDetail()
    expect(wrapper.text()).toContain('login')
  })

  // -- AI Analysis (completed) ---------------------------------------------

  it('renders AI summary', async () => {
    const { wrapper } = await mountDetail()
    expect(wrapper.text()).toContain('Customer unable to log in after recent application update')
  })

  it('renders sentiment badge', async () => {
    const { wrapper } = await mountDetail()
    expect(wrapper.text()).toContain('negative')
  })

  it('renders confidence percentage', async () => {
    const { wrapper } = await mountDetail()
    expect(wrapper.text()).toContain('92%')
  })

  it('renders bug report signal', async () => {
    const { wrapper } = await mountDetail()
    expect(wrapper.text()).toContain('Bug Report')
  })

  it('does not render feature request when false', async () => {
    const { wrapper } = await mountDetail()
    expect(wrapper.text()).not.toContain('Feature Request')
  })

  // -- AI Analysis (pending) -----------------------------------------------

  it('shows pending analysis message', async () => {
    const ticket: TicketDetail = {
      ...completedTicket,
      ai_analysis: {
        ...completedTicket.ai_analysis!,
        status: 'pending',
        sentiment: null,
        summary: null,
        confidence: null,
      },
    }
    const { wrapper } = await mountDetail('1', { data: ticket })
    expect(wrapper.text()).toContain('waiting to analyze')
  })

  // -- AI Analysis (processing) --------------------------------------------

  it('shows processing analysis message', async () => {
    const ticket: TicketDetail = {
      ...completedTicket,
      ai_analysis: {
        ...completedTicket.ai_analysis!,
        status: 'processing',
        sentiment: null,
        summary: null,
        confidence: null,
      },
    }
    const { wrapper } = await mountDetail('1', { data: ticket })
    expect(wrapper.text()).toContain('analyzing this ticket')
  })

  // -- AI Analysis (failed) ------------------------------------------------

  it('shows failed analysis message', async () => {
    const ticket: TicketDetail = {
      ...completedTicket,
      ai_analysis: {
        ...completedTicket.ai_analysis!,
        status: 'failed',
        sentiment: null,
        summary: null,
        confidence: null,
      },
    }
    const { wrapper } = await mountDetail('1', { data: ticket })
    expect(wrapper.text()).toContain("couldn't be completed")
  })

  // -- No AI Analysis -------------------------------------------------------

  it('handles missing AI analysis', async () => {
    const ticket: TicketDetail = {
      ...completedTicket,
      ai_analysis: null,
    }
    const { wrapper } = await mountDetail('1', { data: ticket })
    expect(wrapper.text()).toContain('not been analyzed')
  })

  // -- Missing customer info ------------------------------------------------

  it('handles missing customer name/email', async () => {
    const ticket: TicketDetail = {
      ...completedTicket,
      customer_name: null,
      customer_email: null,
    }
    const { wrapper } = await mountDetail('1', { data: ticket })
    expect(wrapper.text()).toContain('Unknown customer')
  })

  // -- Missing description --------------------------------------------------

  it('handles missing description', async () => {
    const ticket: TicketDetail = {
      ...completedTicket,
      description: null,
    }
    const { wrapper } = await mountDetail('1', { data: ticket })
    expect(wrapper.text()).toContain('No message content')
  })

  // -- 404 error ------------------------------------------------------------

  it('shows not found for 404', async () => {
    const { wrapper } = await mountDetail(
      '999',
      new ApiError({
        type: '/errors/not_found',
        title: 'Not Found',
        status: 404,
        detail: 'Ticket not found',
      }),
    )
    expect(wrapper.text()).toContain('Ticket not found')
  })

  // -- Generic error --------------------------------------------------------

  it('shows generic error message', async () => {
    const { wrapper } = await mountDetail(
      '1',
      new ApiError({
        type: '/errors/internal',
        title: 'Server Error',
        status: 500,
        detail: 'Database unavailable',
      }),
    )
    expect(wrapper.text()).toContain('Unable to load ticket')
    expect(wrapper.text()).toContain('Database unavailable')
  })

  it('error has try again and back buttons', async () => {
    const { wrapper } = await mountDetail('1', new Error('fail'))
    expect(wrapper.text()).toContain('Try again')
    expect(wrapper.text()).toContain('Back to Tickets')
  })

  // -- Back navigation ------------------------------------------------------

  it('back button navigates to tickets list', async () => {
    const { wrapper, router } = await mountDetail()
    const pushSpy = vi.spyOn(router, 'push')

    const backBtn = wrapper.findAll('button').find(b => b.text().includes('Back to Tickets'))
    await backBtn!.trigger('click')

    expect(pushSpy).toHaveBeenCalledWith({ name: 'tickets' })
  })

  // -- All signal types active ----------------------------------------------

  it('shows all signals when all true', async () => {
    const ticket: TicketDetail = {
      ...completedTicket,
      ai_analysis: {
        ...completedTicket.ai_analysis!,
        feature_request: true,
        bug_report: true,
        knowledge_gap: true,
      },
    }
    const { wrapper } = await mountDetail('1', { data: ticket })
    expect(wrapper.text()).toContain('Feature Request')
    expect(wrapper.text()).toContain('Bug Report')
    expect(wrapper.text()).toContain('Knowledge Gap')
  })

  it('shows no signals message when all false', async () => {
    const ticket: TicketDetail = {
      ...completedTicket,
      ai_analysis: {
        ...completedTicket.ai_analysis!,
        feature_request: false,
        bug_report: false,
        knowledge_gap: false,
      },
    }
    const { wrapper } = await mountDetail('1', { data: ticket })
    expect(wrapper.text()).toContain('No specific signals detected')
  })
})
