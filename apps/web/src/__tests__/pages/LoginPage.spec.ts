import { describe, it, expect, beforeEach, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { createRouter, createWebHistory } from 'vue-router'
import LoginPage from '@/pages/LoginPage.vue'
import { ApiError } from '@/api/errors'

// Mock auth API so the store doesn't make real requests
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
      { path: '/login', name: 'login', component: LoginPage },
      { path: '/register', name: 'register', component: { template: '<div />' } },
      { path: '/app/dashboard', name: 'dashboard', component: { template: '<div />' } },
    ],
  })
}

function mountLogin() {
  const pinia = createPinia()
  setActivePinia(pinia)
  const router = makeRouter()
  router.push('/login')

  return mount(LoginPage, {
    global: {
      plugins: [pinia, router],
    },
  })
}

describe('LoginPage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('renders email and password fields', () => {
    const wrapper = mountLogin()
    const inputs = wrapper.findAll('input')
    expect(inputs.length).toBeGreaterThanOrEqual(2)
    expect(inputs[0].attributes('type')).toBe('email')
    expect(inputs[1].attributes('type')).toBe('password')
  })

  it('renders sign in button', () => {
    const wrapper = mountLogin()
    expect(wrapper.text()).toContain('Sign in')
  })

  it('shows validation errors for empty fields', async () => {
    const wrapper = mountLogin()
    await wrapper.find('form').trigger('submit')
    await flushPromises()

    expect(wrapper.text()).toContain('Email is required')
    expect(wrapper.text()).toContain('Password is required')
  })

  it('calls login and redirects on success', async () => {
    const { login } = await import('@/api/auth')
    vi.mocked(login).mockResolvedValue({
      data: { access_token: 'a', refresh_token: 'r' },
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    } as any)

    const pinia = createPinia()
    setActivePinia(pinia)
    const router = makeRouter()
    await router.push('/login')
    await router.isReady()
    const pushSpy = vi.spyOn(router, 'push')

    const wrapper = mount(LoginPage, {
      global: { plugins: [pinia, router] },
    })

    await wrapper.find('input[type="email"]').setValue('a@b.com')
    await wrapper.find('input[type="password"]').setValue('secret')
    await wrapper.find('form').trigger('submit')
    await flushPromises()

    expect(login).toHaveBeenCalledWith({ email: 'a@b.com', password: 'secret' })
    expect(pushSpy).toHaveBeenCalledWith({ name: 'dashboard' })
  })

  it('displays API error on login failure', async () => {
    const { login } = await import('@/api/auth')
    vi.mocked(login).mockRejectedValue(
      new ApiError({
        type: '/errors/unauthorized',
        title: 'Unauthorized',
        status: 401,
        detail: 'Invalid credentials',
      }),
    )

    const wrapper = mountLogin()
    await wrapper.find('input[type="email"]').setValue('a@b.com')
    await wrapper.find('input[type="password"]').setValue('wrong')
    await wrapper.find('form').trigger('submit')
    await flushPromises()

    expect(wrapper.text()).toContain('Invalid credentials')
  })

  it('has a link to register page', () => {
    const wrapper = mountLogin()
    const link = wrapper.find('a[href="/register"]')
    expect(link.exists()).toBe(true)
  })
})
