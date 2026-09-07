import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { setBaseUrl, setTokenAccessor } from '@/api/client'
import * as authApi from '@/api/auth'
import * as ticketsApi from '@/api/tickets'
import * as dashboardApi from '@/api/dashboard'
import * as reportsApi from '@/api/reports'
import * as uploadsApi from '@/api/uploads'
import * as aiApi from '@/api/ai'

// ---------------------------------------------------------------------------
// Shared fetch mock
// ---------------------------------------------------------------------------

function mockFetch(body: unknown = {}, status = 200) {
  return vi.spyOn(globalThis, 'fetch').mockResolvedValue({
    ok: status >= 200 && status < 300,
    status,
    statusText: 'OK',
    headers: new Headers({ 'content-type': 'application/json' }),
    json: () => Promise.resolve(body),
    text: () => Promise.resolve(''),
  } as Response)
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('API modules', () => {
  beforeEach(() => {
    setBaseUrl('/api/v1')
    setTokenAccessor(() => 'test-token')
  })

  afterEach(() => {
    vi.restoreAllMocks()
  })

  // -- Auth -----------------------------------------------------------------

  describe('authApi', () => {
    it('register → POST /api/v1/auth/register', async () => {
      const spy = mockFetch({ data: { user: {}, organization: {} } }, 201)

      await authApi.register({
        first_name: 'Jane',
        last_name: 'Doe',
        email: 'jane@example.com',
        password: 'password',
        password_confirmation: 'password',
        organization_name: 'Acme',
      })

      expect(spy).toHaveBeenCalledWith(
        '/api/v1/auth/register',
        expect.objectContaining({ method: 'POST' }),
      )
    })

    it('register sends noAuth (no Authorization header)', async () => {
      const spy = mockFetch({ data: {} }, 201)

      await authApi.register({
        first_name: 'J',
        last_name: 'D',
        email: 'j@d.com',
        password: 'pw',
        password_confirmation: 'pw',
        organization_name: 'X',
      })

      const headers = spy.mock.calls[0][1]?.headers as Record<string, string>
      expect(headers['Authorization']).toBeUndefined()
    })

    it('login → POST /api/v1/auth/login', async () => {
      const spy = mockFetch({ data: { access_token: 'jwt', refresh_token: 'rt', expires_in: 3600 } })

      await authApi.login({ email: 'jane@example.com', password: 'secret' })

      expect(spy).toHaveBeenCalledWith(
        '/api/v1/auth/login',
        expect.objectContaining({ method: 'POST' }),
      )
    })

    it('refresh → POST /api/v1/auth/refresh', async () => {
      const spy = mockFetch({ data: { access_token: 'new-jwt', refresh_token: 'new-rt', expires_in: 3600 } })

      await authApi.refresh('old-refresh-token')

      expect(spy).toHaveBeenCalledWith(
        '/api/v1/auth/refresh',
        expect.objectContaining({ method: 'POST' }),
      )
      const body = JSON.parse(spy.mock.calls[0][1]?.body as string)
      expect(body.refresh_token).toBe('old-refresh-token')
    })

    it('logout → POST /api/v1/auth/logout', async () => {
      const spy = mockFetch(null, 204)
      // Override for 204
      spy.mockResolvedValue({
        ok: true,
        status: 204,
        statusText: 'No Content',
        headers: new Headers(),
        json: () => Promise.resolve(null),
        text: () => Promise.resolve(''),
      } as Response)

      await authApi.logout('my-refresh-token')

      expect(spy).toHaveBeenCalledWith(
        '/api/v1/auth/logout',
        expect.objectContaining({ method: 'POST' }),
      )
    })
  })

  // -- Tickets --------------------------------------------------------------

  describe('ticketsApi', () => {
    it('list → GET /api/v1/tickets', async () => {
      const spy = mockFetch({ data: [], meta: { page: 1, per_page: 25, total: 0, total_pages: 0 } })

      await ticketsApi.list()

      expect(spy).toHaveBeenCalledWith(
        '/api/v1/tickets',
        expect.objectContaining({ method: 'GET' }),
      )
    })

    it('list with params → GET /api/v1/tickets?page=2&search=bug', async () => {
      const spy = mockFetch({ data: [], meta: {} })

      await ticketsApi.list({ page: 2, search: 'bug' })

      const url = spy.mock.calls[0][0] as string
      expect(url).toContain('/api/v1/tickets?')
      expect(url).toContain('page=2')
      expect(url).toContain('search=bug')
    })

    it('list with filters → includes status, priority, category', async () => {
      const spy = mockFetch({ data: [], meta: {} })

      await ticketsApi.list({ status: 'open', priority: 'high', category: 'billing' })

      const url = spy.mock.calls[0][0] as string
      expect(url).toContain('status=open')
      expect(url).toContain('priority=high')
      expect(url).toContain('category=billing')
    })

    it('get → GET /api/v1/tickets/:id', async () => {
      const spy = mockFetch({ data: { id: 'abc-123', subject: 'Test' } })

      await ticketsApi.getById('abc-123')

      expect(spy).toHaveBeenCalledWith(
        '/api/v1/tickets/abc-123',
        expect.objectContaining({ method: 'GET' }),
      )
    })

    it('get encodes special characters in id', async () => {
      const spy = mockFetch({ data: {} })

      await ticketsApi.getById('id/with/slash')

      const url = spy.mock.calls[0][0] as string
      expect(url).toContain('id%2Fwith%2Fslash')
    })
  })

  // -- Dashboard ------------------------------------------------------------

  describe('dashboardApi', () => {
    it('get → GET /api/v1/dashboard', async () => {
      const spy = mockFetch({ data: { total_tickets: 10 } })

      await dashboardApi.getDashboard()

      expect(spy).toHaveBeenCalledWith(
        '/api/v1/dashboard',
        expect.objectContaining({ method: 'GET' }),
      )
    })
  })

  // -- Reports --------------------------------------------------------------

  describe('reportsApi', () => {
    it('get → GET /api/v1/reports', async () => {
      const spy = mockFetch({ data: { metadata: {}, tickets: {} } })

      await reportsApi.getReport()

      expect(spy).toHaveBeenCalledWith(
        '/api/v1/reports',
        expect.objectContaining({ method: 'GET' }),
      )
    })
  })

  // -- Uploads --------------------------------------------------------------

  describe('uploadsApi', () => {
    it('create → POST /api/v1/uploads with FormData', async () => {
      const spy = mockFetch({ data: { id: 'upload-1', status: 'pending' } }, 201)

      const file = new File(['subject\nLogin bug'], 'tickets.csv', { type: 'text/csv' })
      await uploadsApi.create(file)

      expect(spy).toHaveBeenCalledWith(
        '/api/v1/uploads',
        expect.objectContaining({ method: 'POST' }),
      )

      // Body should be FormData, not JSON
      const callBody = spy.mock.calls[0][1]?.body
      expect(callBody).toBeInstanceOf(FormData)
    })

    it('create sends Authorization header (authenticated endpoint)', async () => {
      const spy = mockFetch({ data: {} }, 201)

      const file = new File(['subject\ntest'], 'test.csv', { type: 'text/csv' })
      await uploadsApi.create(file)

      const headers = spy.mock.calls[0][1]?.headers as Record<string, string>
      expect(headers['Authorization']).toBe('Bearer test-token')
    })
  })

  // -- AI -------------------------------------------------------------------

  describe('aiApi', () => {
    it('getQuota → GET /api/v1/ai/quota', async () => {
      const spy = mockFetch({ data: { ai_monthly_token_limit: 500000, period: '2026-08' } })

      await aiApi.getQuota()

      expect(spy).toHaveBeenCalledWith(
        '/api/v1/ai/quota',
        expect.objectContaining({ method: 'GET' }),
      )
    })

    it('getUsage → GET /api/v1/ai/usage (no params)', async () => {
      const spy = mockFetch({ data: { period: '2026-08', tokens: { used: 1000 } } })

      await aiApi.getUsage()

      expect(spy).toHaveBeenCalledWith(
        '/api/v1/ai/usage',
        expect.objectContaining({ method: 'GET' }),
      )
    })

    it('getUsage with period → GET /api/v1/ai/usage?period=previous', async () => {
      const spy = mockFetch({ data: { period: '2026-07' } })

      await aiApi.getUsage({ period: 'previous' })

      const url = spy.mock.calls[0][0] as string
      expect(url).toContain('/api/v1/ai/usage?')
      expect(url).toContain('period=previous')
    })

    it('getUsage with date range → includes start_date and end_date', async () => {
      const spy = mockFetch({ data: {} })

      await aiApi.getUsage({ start_date: '2026-06-01', end_date: '2026-08-31' })

      const url = spy.mock.calls[0][0] as string
      expect(url).toContain('start_date=2026-06-01')
      expect(url).toContain('end_date=2026-08-31')
    })

    it('getQuota sends Authorization header', async () => {
      const spy = mockFetch({ data: {} })

      await aiApi.getQuota()

      const headers = spy.mock.calls[0][1]?.headers as Record<string, string>
      expect(headers['Authorization']).toBe('Bearer test-token')
    })

    it('getUsage sends Authorization header', async () => {
      const spy = mockFetch({ data: {} })

      await aiApi.getUsage()

      const headers = spy.mock.calls[0][1]?.headers as Record<string, string>
      expect(headers['Authorization']).toBe('Bearer test-token')
    })
  })
})
