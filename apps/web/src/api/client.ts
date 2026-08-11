// ---------------------------------------------------------------------------
// Centralized API client — all HTTP concerns live here
// ---------------------------------------------------------------------------

import { ApiError } from './errors'
import type { ProblemDetail } from './errors'

/** Resolve the API base URL from Vite env, with fallback for tests. */
function getBaseUrl(): string {
  try {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const env = (import.meta as any).env as Record<string, string> | undefined
    return env?.VITE_API_BASE_URL ?? '/api/v1'
  } catch {
    return '/api/v1'
  }
}

let baseUrl: string = getBaseUrl()

/** Override the base URL (useful in tests). */
export function setBaseUrl(url: string): void {
  baseUrl = url
}

/** Get the current base URL. */
export function getConfiguredBaseUrl(): string {
  return baseUrl
}

// ---------------------------------------------------------------------------
// Token accessor — set by the auth store
// ---------------------------------------------------------------------------

type TokenAccessor = () => string | null
let getToken: TokenAccessor = () => null

/** Register the function the client calls to obtain the current JWT. */
export function setTokenAccessor(accessor: TokenAccessor): void {
  getToken = accessor
}

// ---------------------------------------------------------------------------
// Default timeout (ms). Set to 0 to disable.
// ---------------------------------------------------------------------------

const DEFAULT_TIMEOUT_MS = 30_000

// ---------------------------------------------------------------------------
// Core request function
// ---------------------------------------------------------------------------

export interface RequestOptions {
  /** Skip attaching the Authorization header (for public endpoints). */
  noAuth?: boolean
  /** Custom AbortSignal for caller-controlled cancellation. */
  signal?: AbortSignal
  /** Timeout in milliseconds. Defaults to 30 000. Set 0 to disable. */
  timeout?: number
}

/**
 * Low-level request helper.
 *
 * - Builds the full URL from `baseUrl` + path.
 * - Attaches `Authorization: Bearer <token>` unless `noAuth` is set.
 * - Sends/receives JSON by default.
 * - Parses RFC 9457 Problem Details on error responses.
 * - Returns `null` for 204 No Content.
 */
export async function request<T>(
  method: string,
  path: string,
  body?: unknown,
  options: RequestOptions = {},
): Promise<T> {
  const url = `${baseUrl}${path}`

  const headers: Record<string, string> = {}

  // Attach auth header unless explicitly skipped
  if (!options.noAuth) {
    const token = getToken()
    if (token) {
      headers['Authorization'] = `Bearer ${token}`
    }
  }

  // Set content type for JSON bodies (skip for FormData — browser sets boundary)
  if (body !== undefined && !(body instanceof FormData)) {
    headers['Content-Type'] = 'application/json'
  }

  // Timeout via AbortController
  let timeoutId: ReturnType<typeof setTimeout> | undefined
  let controller: AbortController | undefined
  const timeoutMs = options.timeout ?? DEFAULT_TIMEOUT_MS

  if (timeoutMs > 0 && !options.signal) {
    controller = new AbortController()
    timeoutId = setTimeout(() => controller!.abort(), timeoutMs)
  }

  const signal = options.signal ?? controller?.signal

  let response: Response
  try {
    response = await fetch(url, {
      method,
      headers,
      body: body instanceof FormData
        ? body
        : body !== undefined
          ? JSON.stringify(body)
          : undefined,
      signal,
    })
  } catch (err: unknown) {
    if (timeoutId !== undefined) clearTimeout(timeoutId)

    // Distinguish abort (timeout) from network failures
    if (err instanceof DOMException && err.name === 'AbortError') {
      throw new ApiError({
        type: '/errors/timeout',
        title: 'Request Timeout',
        status: 0,
        detail: `Request to ${path} timed out after ${timeoutMs}ms`,
      })
    }
    throw new ApiError({
      type: '/errors/network',
      title: 'Network Error',
      status: 0,
      detail: err instanceof Error ? err.message : 'Unknown network error',
    })
  } finally {
    if (timeoutId !== undefined) clearTimeout(timeoutId)
  }

  // 204 No Content — nothing to parse
  if (response.status === 204) {
    return null as T
  }

  // Error responses
  if (!response.ok) {
    const contentType = response.headers.get('content-type') ?? ''

    if (contentType.includes('application/json')) {
      const problem = (await response.json()) as ProblemDetail
      throw new ApiError(problem)
    }

    // Non-JSON error (e.g. HTML error page from a proxy)
    const text = await response.text()
    throw new ApiError({
      type: '/errors/unexpected',
      title: response.statusText || 'Request Failed',
      status: response.status,
      detail: text || `HTTP ${response.status}`,
    })
  }

  // Successful JSON response
  return (await response.json()) as T
}

// ---------------------------------------------------------------------------
// Convenience helpers
// ---------------------------------------------------------------------------

export function get<T>(path: string, options?: RequestOptions): Promise<T> {
  return request<T>('GET', path, undefined, options)
}

export function post<T>(path: string, body?: unknown, options?: RequestOptions): Promise<T> {
  return request<T>('POST', path, body, options)
}
