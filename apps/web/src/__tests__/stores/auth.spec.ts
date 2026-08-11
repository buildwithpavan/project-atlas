import { describe, it, expect, beforeEach, vi } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { useAuthStore } from '@/stores/auth'
import * as authApi from '@/api/auth'

vi.mock('@/api/auth', () => ({
  login: vi.fn(),
  register: vi.fn(),
  logout: vi.fn(),
  refresh: vi.fn(),
}))

describe('auth store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
  })

  // -- Initial state --------------------------------------------------------

  it('starts unauthenticated', () => {
    const store = useAuthStore()
    expect(store.isAuthenticated).toBe(false)
    expect(store.accessToken).toBeNull()
    expect(store.refreshToken).toBeNull()
    expect(store.isRestoring).toBe(false)
  })

  // -- setTokens / clearAuth ------------------------------------------------

  it('sets tokens and becomes authenticated', () => {
    const store = useAuthStore()
    store.setTokens('access-jwt', 'refresh-opaque')

    expect(store.isAuthenticated).toBe(true)
    expect(store.accessToken).toBe('access-jwt')
    expect(store.refreshToken).toBe('refresh-opaque')
  })

  it('clears authentication', () => {
    const store = useAuthStore()
    store.setTokens('access-jwt', 'refresh-opaque')
    store.clearAuth()

    expect(store.isAuthenticated).toBe(false)
    expect(store.accessToken).toBeNull()
    expect(store.refreshToken).toBeNull()
  })

  // -- login ----------------------------------------------------------------

  it('login stores tokens on success', async () => {
    vi.mocked(authApi.login).mockResolvedValue({
      data: { access_token: 'a', refresh_token: 'r' },
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    } as any)

    const store = useAuthStore()
    await store.login({ email: 'a@b.com', password: 'secret' })

    expect(authApi.login).toHaveBeenCalledWith({ email: 'a@b.com', password: 'secret' })
    expect(store.isAuthenticated).toBe(true)
    expect(store.accessToken).toBe('a')
  })

  it('login propagates API errors', async () => {
    vi.mocked(authApi.login).mockRejectedValue(new Error('Invalid credentials'))

    const store = useAuthStore()
    await expect(store.login({ email: 'a@b.com', password: 'wrong' })).rejects.toThrow('Invalid credentials')
    expect(store.isAuthenticated).toBe(false)
  })

  // -- register -------------------------------------------------------------

  it('register calls API without storing tokens', async () => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    vi.mocked(authApi.register).mockResolvedValue({} as any)

    const store = useAuthStore()
    await store.register({
      first_name: 'J',
      last_name: 'D',
      email: 'j@d.com',
      password: 'pass1234',
      password_confirmation: 'pass1234',
      organization_name: 'Acme',
    })

    expect(authApi.register).toHaveBeenCalled()
    expect(store.isAuthenticated).toBe(false)
  })

  // -- logout ---------------------------------------------------------------

  it('logout clears auth and calls API', async () => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    vi.mocked(authApi.logout).mockResolvedValue(null as any)

    const store = useAuthStore()
    store.setTokens('a', 'r')
    await store.logout()

    expect(store.isAuthenticated).toBe(false)
    expect(authApi.logout).toHaveBeenCalledWith('r')
  })

  it('logout clears auth even if API call fails', async () => {
    vi.mocked(authApi.logout).mockRejectedValue(new Error('fail'))

    const store = useAuthStore()
    store.setTokens('a', 'r')
    await store.logout()

    expect(store.isAuthenticated).toBe(false)
  })

  // -- restoreSession -------------------------------------------------------

  it('restoreSession refreshes tokens on success', async () => {
    vi.mocked(authApi.refresh).mockResolvedValue({
      data: { access_token: 'new-a', refresh_token: 'new-r' },
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    } as any)

    const store = useAuthStore()
    store.setTokens('old-a', 'old-r')
    const result = await store.restoreSession()

    expect(result).toBe(true)
    expect(store.accessToken).toBe('new-a')
    expect(store.isRestoring).toBe(false)
  })

  it('restoreSession returns false and clears on failure', async () => {
    vi.mocked(authApi.refresh).mockRejectedValue(new Error('expired'))

    const store = useAuthStore()
    store.setTokens('a', 'r')
    const result = await store.restoreSession()

    expect(result).toBe(false)
    expect(store.isAuthenticated).toBe(false)
    expect(store.isRestoring).toBe(false)
  })

  it('restoreSession returns false without token', async () => {
    const store = useAuthStore()
    const result = await store.restoreSession()

    expect(result).toBe(false)
    expect(authApi.refresh).not.toHaveBeenCalled()
  })

  // -- attemptRefresh -------------------------------------------------------

  it('attemptRefresh returns true on success', async () => {
    vi.mocked(authApi.refresh).mockResolvedValue({
      data: { access_token: 'new-a', refresh_token: 'new-r' },
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    } as any)

    const store = useAuthStore()
    store.setTokens('a', 'r')
    const result = await store.attemptRefresh()

    expect(result).toBe(true)
    expect(store.accessToken).toBe('new-a')
  })

  it('attemptRefresh returns false and clears on failure', async () => {
    vi.mocked(authApi.refresh).mockRejectedValue(new Error('fail'))

    const store = useAuthStore()
    store.setTokens('a', 'r')
    const result = await store.attemptRefresh()

    expect(result).toBe(false)
    expect(store.isAuthenticated).toBe(false)
  })
})
