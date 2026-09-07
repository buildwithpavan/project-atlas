// ---------------------------------------------------------------------------
// RFC 9457 Problem Details error model
// ---------------------------------------------------------------------------

/**
 * Typed representation of an RFC 9457 Problem Details response
 * returned by the Voceive Rails API.
 */
export class ApiError extends Error {
  /** Problem type URI, e.g. "/errors/unauthorized" */
  readonly type: string
  /** Short summary, e.g. "Unauthorized" */
  readonly title: string
  /** HTTP status code */
  readonly status: number
  /** Human-readable explanation */
  readonly detail: string
  /** Field-level validation errors (present on 422 responses) */
  readonly errors?: Record<string, string[]>

  constructor(problem: ProblemDetail) {
    super(problem.detail)
    this.name = 'ApiError'
    this.type = problem.type
    this.title = problem.title
    this.status = problem.status
    this.detail = problem.detail
    this.errors = problem.errors
  }

  /** Whether this error includes field-level validation errors */
  get isValidation(): boolean {
    return this.status === 422 && this.errors !== undefined
  }
}

/** Raw Problem Details shape before it becomes an ApiError instance */
export interface ProblemDetail {
  type: string
  title: string
  status: number
  detail: string
  errors?: Record<string, string[]>
}
