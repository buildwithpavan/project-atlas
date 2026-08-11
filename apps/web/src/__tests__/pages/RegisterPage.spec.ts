import { describe, it, expect, beforeEach, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { createRouter, createWebHistory } from 'vue-router'
import RegisterPage from '@/pages/RegisterPage.vue'
import { ApiError } from '@/api/errors'

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
      { path: '/register', name: 'register', component: RegisterPage },
      { path: '/login', name: 'login', component: { template: '<div />' } },
      { path: '/app/dashboard', name: 'dashboard', component: { template: '<div />' } },
    ],
  })
}

function mountRegister() {
  const pinia = createPinia()
  setActivePinia(pinia)
  const router = makeRouter()
  router.push('/register')

  return mount(RegisterPage, {
    global: { plugins: [pinia, router] },
  })
}

describe('RegisterPage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('renders all registration fields', () => {
    const wrapper = mountRegister()
    const inputs = wrapper.findAll('input')
    // first_name, last_name, email, password, password_confirmation, organization_name
    expect(inputs.length).toBe(6)
  })

  it('shows validation errors for empty fields', async () => {
    const wrapper = mountRegister()
    await wrapper.find('form').trigger('submit')
    await flushPromises()

    expect(wrapper.text()).toContain('First name is required')
    expect(wrapper.text()).toContain('Email is required')
    expect(wrapper.text()).toContain('Password is required')
    expect(wrapper.text()).toContain('Organization name is required')
  })

  it('shows password mismatch error', async () => {
    const wrapper = mountRegister()
    const inputs = wrapper.findAll('input')
    await inputs[0].setValue('Jane')
    await inputs[1].setValue('Doe')
    await inputs[2].setValue('j@d.com')
    await inputs[3].setValue('password1')
    await inputs[4].setValue('password2')
    await inputs[5].setValue('Acme')
    await wrapper.find('form').trigger('submit')
    await flushPromises()

    expect(wrapper.text()).toContain('Passwords do not match')
  })

  it('calls register and redirects to login on success', async () => {
    const { register } = await import('@/api/auth')
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    vi.mocked(register).mockResolvedValue({} as any)

    const pinia = createPinia()
    setActivePinia(pinia)
    const router = makeRouter()
    await router.push('/register')
    await router.isReady()
    const pushSpy = vi.spyOn(router, 'push')

    const wrapper = mount(RegisterPage, {
      global: { plugins: [pinia, router] },
    })

    const inputs = wrapper.findAll('input')
    await inputs[0].setValue('Jane')
    await inputs[1].setValue('Doe')
    await inputs[2].setValue('j@d.com')
    await inputs[3].setValue('pass1234')
    await inputs[4].setValue('pass1234')
    await inputs[5].setValue('Acme')
    await wrapper.find('form').trigger('submit')
    await flushPromises()

    expect(register).toHaveBeenCalled()
    expect(pushSpy).toHaveBeenCalledWith({ name: 'login', query: { registered: 'true' } })
  })

  it('displays server-side validation errors', async () => {
    const { register } = await import('@/api/auth')
    vi.mocked(register).mockRejectedValue(
      new ApiError({
        type: '/errors/validation',
        title: 'Validation Error',
        status: 422,
        detail: 'User validation failed',
        errors: { email: ['has already been taken'] },
      }),
    )

    const wrapper = mountRegister()
    const inputs = wrapper.findAll('input')
    await inputs[0].setValue('Jane')
    await inputs[1].setValue('Doe')
    await inputs[2].setValue('taken@d.com')
    await inputs[3].setValue('pass1234')
    await inputs[4].setValue('pass1234')
    await inputs[5].setValue('Acme')
    await wrapper.find('form').trigger('submit')
    await flushPromises()

    expect(wrapper.text()).toContain('has already been taken')
  })

  it('has a link to login page', () => {
    const wrapper = mountRegister()
    const link = wrapper.find('a[href="/login"]')
    expect(link.exists()).toBe(true)
  })
})
