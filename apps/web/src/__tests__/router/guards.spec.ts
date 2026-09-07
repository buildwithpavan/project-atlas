import { describe, it, expect, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import router, { initGuard } from '@/router'

// We need to test the guard behaviour by simulating navigation.
// Use a reactive flag to control isAuthenticated.

describe('router guards', () => {
  let authenticated: boolean

  beforeEach(async () => {
    setActivePinia(createPinia())
    authenticated = false
    initGuard(() => ({ isAuthenticated: authenticated }))
    // Reset router to a neutral location that no test targets directly
    await router.push('/design-system')
    await router.isReady()
  })

  it('allows unauthenticated access to /login', async () => {
    await router.push('/login')
    expect(router.currentRoute.value.name).toBe('login')
  })

  it('allows unauthenticated access to /register', async () => {
    await router.push('/register')
    expect(router.currentRoute.value.name).toBe('register')
  })

  it('redirects unauthenticated user from /app/dashboard to /login', async () => {
    await router.push('/app/dashboard')
    expect(router.currentRoute.value.name).toBe('login')
  })

  it('allows authenticated user to access /app/dashboard', async () => {
    authenticated = true
    await router.push('/app/dashboard')
    expect(router.currentRoute.value.name).toBe('dashboard')
  })

  it('redirects authenticated user from /login to /app/dashboard', async () => {
    authenticated = true
    await router.push('/login')
    expect(router.currentRoute.value.name).toBe('dashboard')
  })

  it('redirects authenticated user from /register to /app/dashboard', async () => {
    authenticated = true
    await router.push('/register')
    expect(router.currentRoute.value.name).toBe('dashboard')
  })

  it('allows access to /design-system regardless of auth', async () => {
    await router.push('/design-system')
    expect(router.currentRoute.value.name).toBe('design-system')
  })

  it('allows unauthenticated access to landing page (/)', async () => {
    await router.push('/')
    expect(router.currentRoute.value.name).toBe('landing')
  })

  it('redirects authenticated user from / to /app/dashboard', async () => {
    authenticated = true
    await router.push('/')
    expect(router.currentRoute.value.name).toBe('dashboard')
  })
})
