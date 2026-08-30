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

function setupMock(response: ListEnvelope<Theme> | Error = loadedResponse) {
  if (response instanceof Error) {
    vi.mocked(themesApi.list).mockRejectedValue(response)
  } else {
    vi.mocked(themesApi.list).mockResolvedValue(response)
  }
  vi.mocked(themesApi.detect).mockResolvedValue({
    data: { message: 'Theme detection started' },
  })
}

function makeRouter() {
  return createRouter({
    history: createWebHistory(),
    routes: [
      { path: '/app/themes', name: 'themes', component: ThemesPage },
      { path: '/app/themes/:id', name: 'theme-detail', component: { template: '<div />' } },
    ],
  })
}

async function mountPage(response?: ListEnvelope<Theme> | Error) {
  setupMock(response)
  const pinia = createPinia()
  setActivePinia(pinia)
  const router = makeRouter()
  await router.push('/app/themes')
  await router.isReady()

  const wrapper = mount(ThemesPage, {
    global: { plugins: [pinia, router] },
  })
  await flushPromises()
  return wrapper
}

describe('ThemesPage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('shows loading text initially', () => {
    setupMock()
    const pinia = createPinia()
    setActivePinia(pinia)
    const router = makeRouter()
    const wrapper = mount(ThemesPage, {
      global: { plugins: [pinia, router] },
    })
    expect(wrapper.text()).toContain('Loading themes')
  })

  it('renders page header', async () => {
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('Themes')
    expect(wrapper.text()).toContain('Recurring patterns')
  })

  it('renders theme cards when data is loaded', async () => {
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('Billing Issues')
    expect(wrapper.text()).toContain('Login Failures')
  })

  it('shows severity badges', async () => {
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('high')
    expect(wrapper.text()).toContain('critical')
  })

  it('shows ticket counts', async () => {
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('5 tickets')
    expect(wrapper.text()).toContain('8 tickets')
  })

  it('shows recommended actions', async () => {
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('Investigate billing system')
    expect(wrapper.text()).toContain('Fix auth flow')
  })

  it('sorts themes by severity (critical first)', async () => {
    const wrapper = await mountPage()
    const titles = wrapper.findAll('h3').map((h) => h.text())
    expect(titles[0]).toBe('Login Failures')
    expect(titles[1]).toBe('Billing Issues')
  })

  it('shows empty state when no themes', async () => {
    const wrapper = await mountPage(emptyResponse)
    expect(wrapper.text()).toContain('No themes detected')
  })

  it('shows error state on API failure', async () => {
    const wrapper = await mountPage(new Error('Network error'))
    expect(wrapper.text()).toContain('Failed to load themes')
  })

  it('has a Detect Themes button', async () => {
    const wrapper = await mountPage()
    const button = wrapper.find('button')
    expect(button.text()).toContain('Detect Themes')
  })

  it('calls detect API when button clicked', async () => {
    const wrapper = await mountPage()
    await wrapper.find('button').trigger('click')
    expect(themesApi.detect).toHaveBeenCalled()
  })

  it('has status and severity filter dropdowns', async () => {
    const wrapper = await mountPage()
    const selects = wrapper.findAll('select')
    expect(selects.length).toBe(2)
  })
})
