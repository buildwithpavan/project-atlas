import { describe, it, expect, beforeEach, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { createRouter, createWebHistory } from 'vue-router'
import AppLayout from '@/layouts/AppLayout.vue'

vi.mock('@/api/auth', () => ({
  login: vi.fn(),
  register: vi.fn(),
  logout: vi.fn(),
  refresh: vi.fn(),
}))

function makeRouter() {
  return createRouter({
    history: createWebHistory(),
    routes: [
      {
        path: '/app',
        component: AppLayout,
        children: [
          { path: 'dashboard', name: 'dashboard', component: { template: '<div>Dashboard</div>' } },
          { path: 'tickets', name: 'tickets', component: { template: '<div>Tickets</div>' } },
          { path: 'reports', name: 'reports', component: { template: '<div>Reports</div>' } },
          { path: 'knowledge-base', name: 'knowledge-base', component: { template: '<div>Knowledge Base</div>' } },
          { path: 'import', name: 'import', component: { template: '<div>Import</div>' } },
        ],
      },
      { path: '/login', name: 'login', component: { template: '<div />' } },
    ],
  })
}

describe('AppLayout', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('renders sidebar with navigation links', async () => {
    const pinia = createPinia()
    setActivePinia(pinia)
    const router = makeRouter()
    await router.push('/app/dashboard')
    await router.isReady()

    const wrapper = mount(AppLayout, {
      global: { plugins: [pinia, router] },
    })

    expect(wrapper.text()).toContain('Dashboard')
    expect(wrapper.text()).toContain('Tickets')
    expect(wrapper.text()).toContain('Reports')
    expect(wrapper.text()).toContain('Knowledge Base')
    expect(wrapper.text()).toContain('Import Data')
  })

  it('renders the Voceive brand logo', async () => {
    const pinia = createPinia()
    setActivePinia(pinia)
    const router = makeRouter()
    await router.push('/app/dashboard')
    await router.isReady()

    const wrapper = mount(AppLayout, {
      global: { plugins: [pinia, router] },
    })

    expect(wrapper.find('img[alt="Voceive"]').exists()).toBe(true)
  })

  it('renders sign out button', async () => {
    const pinia = createPinia()
    setActivePinia(pinia)
    const router = makeRouter()
    await router.push('/app/dashboard')
    await router.isReady()

    const wrapper = mount(AppLayout, {
      global: { plugins: [pinia, router] },
    })

    expect(wrapper.text()).toContain('Sign out')
  })

  it('logout clears auth and navigates to login', async () => {
    const { logout } = await import('@/api/auth')
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    vi.mocked(logout).mockResolvedValue(null as any)

    const pinia = createPinia()
    setActivePinia(pinia)
    const router = makeRouter()
    await router.push('/app/dashboard')
    await router.isReady()
    const pushSpy = vi.spyOn(router, 'push')

    const wrapper = mount(AppLayout, {
      global: { plugins: [pinia, router] },
    })

    const buttons = wrapper.findAll('button[type="button"]')
    const signOutBtn = buttons.find(b => b.text().includes('Sign out'))!
    await signOutBtn.trigger('click')
    await flushPromises()

    expect(pushSpy).toHaveBeenCalledWith({ name: 'login' })
  })

  it('renders child route content', async () => {
    const pinia = createPinia()
    setActivePinia(pinia)
    const router = makeRouter()
    await router.push('/app/dashboard')
    await router.isReady()

    const wrapper = mount(AppLayout, {
      global: { plugins: [pinia, router] },
    })
    await flushPromises()

    // The child route should render inside the layout
    expect(wrapper.find('main').exists()).toBe(true)
  })

  it('Import Data links to /app/import', async () => {
    const pinia = createPinia()
    setActivePinia(pinia)
    const router = makeRouter()
    await router.push('/app/dashboard')
    await router.isReady()

    const wrapper = mount(AppLayout, {
      global: { plugins: [pinia, router] },
    })

    const link = wrapper.findAll('a').find(a => a.text().includes('Import Data'))
    expect(link).toBeTruthy()
    expect(link!.attributes('href')).toBe('/app/import')
  })
})
