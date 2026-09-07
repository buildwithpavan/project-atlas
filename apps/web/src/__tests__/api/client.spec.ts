import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { request, get, post, setBaseUrl, setTokenAccessor, getConfiguredBaseUrl } from '@/api/client'
import { ApiError } from '@/api/errors'

// ---------------------------------------------------------------------------
// fetch mock helper
// ---------------------------------------------------------------------------

function mockFetch(response: Partial<Response> & { json?: () => Promise<unknown>; text?: () => Promise<string> }) {
  const res = {
    ok: response.ok ?? true,
    status: response.status ?? 200,
    statusText: response.statusText ?? 'OK',
    headers: response.headers ?? new Headers({ 'content-type': 'application/json' }),
    json: response.json ?? (() => Promise.resolve({})),
    text: response.text ?? (() => Promise.resolve('')),
  } as Response

  return vi.spyOn(globalThis, 'fetch').mockResolvedValue(res)
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('API client', () => {
  beforeEach(() => {
    setBaseUrl('/api/v1')
    setTokenAccessor(() => null)
  })

  afterEach(() => {
    vi.restoreAllMocks()
  })

  // -- Base URL configuration -----------------------------------------------

  describe('base URL configuration', () => {
    it('uses the configured base URL', async () => {
      setBaseUrl('https://api.example.com')
      const spy = mockFetch({ json: () => Promise.resolve({ ok: true }) })

      await get('/health')

      expect(spy).toHaveBeenCalledWith(
        'https://api.example.com/health',
        expect.any(Object),
      )
    })

    it('reports configured base URL via getter', () => {
      setBaseUrl('https://custom.api')
      expect(getConfiguredBaseUrl()).toBe('https://custom.api')
    })
  })

  // -- GET request ----------------------------------------------------------

  describe('GET requests', () => {
    it('sends a GET request and returns parsed JSON', async () => {
      const payload = { data: { id: '1', name: 'Test' } }
      const spy = mockFetch({ json: () => Promise.resolve(payload) })

      const result = await get('/tickets')

      expect(spy).toHaveBeenCalledWith(
        '/api/v1/tickets',
        expect.objectContaining({ method: 'GET' }),
      )
      expect(result).toEqual(payload)
    })
  })

  // -- POST request ---------------------------------------------------------

  describe('POST requests', () => {
    it('sends a POST request with JSON body', async () => {
      const body = { email: 'a@b.com', password: 'secret' }
      const payload = { data: { access_token: 'jwt' } }
      const spy = mockFetch({ json: () => Promise.resolve(payload) })

      const result = await post('/auth/login', body)

      expect(spy).toHaveBeenCalledWith(
        '/api/v1/auth/login',
        expect.objectContaining({
          method: 'POST',
          body: JSON.stringify(body),
        }),
      )
      // Verify Content-Type header
      const callHeaders = spy.mock.calls[0][1]?.headers as Record<string, string>
      expect(callHeaders['Content-Type']).toBe('application/json')
      expect(result).toEqual(payload)
    })

    it('does not set Content-Type for FormData bodies', async () => {
      const form = new FormData()
      form.append('file', new Blob(['csv'], { type: 'text/csv' }), 'test.csv')
      const spy = mockFetch({ json: () => Promise.resolve({ data: {} }) })

      await post('/uploads', form)

      const callHeaders = spy.mock.calls[0][1]?.headers as Record<string, string>
      expect(callHeaders['Content-Type']).toBeUndefined()
      // FormData should be sent directly (not JSON-stringified)
      expect(spy.mock.calls[0][1]?.body).toBe(form)
    })
  })

  // -- Authorization header -------------------------------------------------

  describe('authorization header', () => {
    it('attaches Bearer token when accessor provides one', async () => {
      setTokenAccessor(() => 'test-jwt-token')
      const spy = mockFetch({ json: () => Promise.resolve({}) })

      await get('/tickets')

      const callHeaders = spy.mock.calls[0][1]?.headers as Record<string, string>
      expect(callHeaders['Authorization']).toBe('Bearer test-jwt-token')
    })

    it('omits Authorization header when accessor returns null', async () => {
      setTokenAccessor(() => null)
      const spy = mockFetch({ json: () => Promise.resolve({}) })

      await get('/tickets')

      const callHeaders = spy.mock.calls[0][1]?.headers as Record<string, string>
      expect(callHeaders['Authorization']).toBeUndefined()
    })

    it('skips Authorization header when noAuth is set', async () => {
      setTokenAccessor(() => 'should-not-appear')
      const spy = mockFetch({ json: () => Promise.resolve({}) })

      await get('/auth/login', { noAuth: true })

      const callHeaders = spy.mock.calls[0][1]?.headers as Record<string, string>
      expect(callHeaders['Authorization']).toBeUndefined()
    })
  })

  // -- 204 No Content -------------------------------------------------------

  describe('204 No Content', () => {
    it('returns null for 204 responses', async () => {
      mockFetch({ status: 204, ok: true })

      const result = await post('/auth/logout', { refresh_token: 'tok' })

      expect(result).toBeNull()
    })
  })

  // -- Problem Details error parsing ----------------------------------------

  describe('Problem Details error parsing', () => {
    it('throws ApiError with Problem Details fields on JSON error', async () => {
      const problem = {
        type: '/errors/unauthorized',
        title: 'Unauthorized',
        status: 401,
        detail: 'Invalid credentials',
      }
      mockFetch({
        ok: false,
        status: 401,
        statusText: 'Unauthorized',
        headers: new Headers({ 'content-type': 'application/json' }),
        json: () => Promise.resolve(problem),
      })

      await expect(get('/tickets')).rejects.toThrow(ApiError)

      try {
        await get('/tickets')
      } catch (err) {
        const apiErr = err as ApiError
        expect(apiErr.type).toBe('/errors/unauthorized')
        expect(apiErr.title).toBe('Unauthorized')
        expect(apiErr.status).toBe(401)
        expect(apiErr.detail).toBe('Invalid credentials')
        expect(apiErr.name).toBe('ApiError')
      }
    })

    it('includes validation errors on 422 response', async () => {
      const problem = {
        type: '/errors/validation',
        title: 'Validation Error',
        status: 422,
        detail: 'User validation failed',
        errors: { email: ['has already been taken'] },
      }
      mockFetch({
        ok: false,
        status: 422,
        headers: new Headers({ 'content-type': 'application/json' }),
        json: () => Promise.resolve(problem),
      })

      try {
        await post('/auth/register', {})
      } catch (err) {
        const apiErr = err as ApiError
        expect(apiErr.isValidation).toBe(true)
        expect(apiErr.errors).toEqual({ email: ['has already been taken'] })
      }
    })
  })

  // -- Non-JSON error response fallback -------------------------------------

  describe('non-JSON error response', () => {
    it('falls back to text body when error is not JSON', async () => {
      mockFetch({
        ok: false,
        status: 502,
        statusText: 'Bad Gateway',
        headers: new Headers({ 'content-type': 'text/html' }),
        text: () => Promise.resolve('<html>Bad Gateway</html>'),
      })

      try {
        await get('/tickets')
      } catch (err) {
        const apiErr = err as ApiError
        expect(apiErr.status).toBe(502)
        expect(apiErr.title).toBe('Bad Gateway')
        expect(apiErr.detail).toBe('<html>Bad Gateway</html>')
        expect(apiErr.type).toBe('/errors/unexpected')
      }
    })
  })

  // -- Network / fetch failure ----------------------------------------------

  describe('network failure', () => {
    it('throws ApiError with network type on fetch failure', async () => {
      vi.spyOn(globalThis, 'fetch').mockRejectedValue(new TypeError('Failed to fetch'))

      try {
        await get('/tickets', { timeout: 0 })
      } catch (err) {
        const apiErr = err as ApiError
        expect(apiErr.type).toBe('/errors/network')
        expect(apiErr.title).toBe('Network Error')
        expect(apiErr.status).toBe(0)
        expect(apiErr.detail).toBe('Failed to fetch')
      }
    })
  })

  // -- Request abort / timeout ----------------------------------------------

  describe('request timeout', () => {
    it('throws ApiError with timeout type on abort', async () => {
      vi.spyOn(globalThis, 'fetch').mockRejectedValue(
        new DOMException('The operation was aborted.', 'AbortError'),
      )

      try {
        await get('/slow-endpoint', { timeout: 100 })
      } catch (err) {
        const apiErr = err as ApiError
        expect(apiErr.type).toBe('/errors/timeout')
        expect(apiErr.title).toBe('Request Timeout')
        expect(apiErr.status).toBe(0)
      }
    })

    it('supports caller-provided AbortSignal', async () => {
      const controller = new AbortController()
      controller.abort()

      vi.spyOn(globalThis, 'fetch').mockRejectedValue(
        new DOMException('The operation was aborted.', 'AbortError'),
      )

      await expect(
        request('GET', '/test', undefined, { signal: controller.signal }),
      ).rejects.toThrow(ApiError)
    })
  })
})
