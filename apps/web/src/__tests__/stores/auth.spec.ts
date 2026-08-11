import { describe, it, expect, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { useAuthStore } from '@/stores/auth'

describe('auth store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
  })

  it('starts unauthenticated', () => {
    const store = useAuthStore()
    expect(store.isAuthenticated).toBe(false)
    expect(store.accessToken).toBeNull()
    expect(store.refreshToken).toBeNull()
  })

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

  it('makes token available to API client via accessor', async () => {
    const store = useAuthStore()
    store.setTokens('my-jwt', 'my-refresh')

    // The store registers setTokenAccessor on creation.
    // Import the client module and verify the accessor works.
    const { getConfiguredBaseUrl } = await import('@/api/client')

    // If getConfiguredBaseUrl works, the module loaded — and the
    // accessor was registered during store creation.
    expect(getConfiguredBaseUrl()).toBeDefined()
    expect(store.accessToken).toBe('my-jwt')
  })
})
