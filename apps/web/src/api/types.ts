// ---------------------------------------------------------------------------
// Domain types aligned with docs/openapi.yaml
// ---------------------------------------------------------------------------

// -- Identity ---------------------------------------------------------------

export interface User {
  id: string
  email: string
  first_name: string
  last_name: string
}

export interface Organization {
  id: string
  name: string
  slug: string
}

export interface AuthTokens {
  access_token: string
  refresh_token: string
  expires_in: number
}

// -- Uploads ----------------------------------------------------------------

export type UploadStatus = 'pending' | 'processing' | 'completed' | 'failed'

export interface Upload {
  id: string
  filename: string
  status: UploadStatus
  total_records: number | null
  processed_records: number
  failed_records: number
  created_at: string
  updated_at: string
}

// -- Tickets ----------------------------------------------------------------

export interface Ticket {
  id: string
  subject: string
  status: string | null
  priority: string | null
  category: string | null
  customer_name: string | null
  customer_email: string | null
  created_at: string
  updated_at: string
}

export interface TicketDetail extends Ticket {
  description: string | null
  upload_id: string
  ai_analysis: AiAnalysis | null
}

// -- AI Analysis ------------------------------------------------------------

export type AiAnalysisStatus = 'pending' | 'processing' | 'completed' | 'failed'
export type Sentiment = 'positive' | 'negative' | 'neutral' | 'mixed'

export interface AiAnalysis {
  id: string
  status: AiAnalysisStatus
  sentiment: Sentiment | null
  summary: string | null
  category: string | null
  confidence: number | null
  feature_request: boolean | null
  bug_report: boolean | null
  knowledge_gap: boolean | null
  processed_at: string | null
}

// -- Pagination -------------------------------------------------------------

export interface PaginationMeta {
  page: number
  per_page: number
  total: number
  total_pages: number
}

// -- Dashboard --------------------------------------------------------------

export interface Dashboard {
  total_tickets: number
  analyzed_tickets: number
  sentiment_distribution: Record<string, number>
  top_categories: Record<string, number>
  feature_requests: number
  bug_reports: number
}

// -- Reports ----------------------------------------------------------------

export interface Report {
  metadata: {
    generated_at: string
    organization_name: string
  }
  tickets: {
    total: number
    analyzed: number
    unanalyzed: number
  }
  sentiment: {
    distribution: Record<string, number>
    percentages: Record<string, number>
  }
  categories: {
    distribution: Record<string, number>
    top: Record<string, number>
  }
  classifications: {
    feature_requests: number
    bug_reports: number
    knowledge_gaps: number
  }
  status_distribution: Record<string, number>
  priority_distribution: Record<string, number>
  timeline: Record<string, number>
}

// -- API envelope wrappers --------------------------------------------------

export interface DataEnvelope<T> {
  data: T
}

export interface PaginatedEnvelope<T> {
  data: T[]
  meta: PaginationMeta
}

// -- Request parameter types ------------------------------------------------

export interface RegisterParams {
  first_name: string
  last_name: string
  email: string
  password: string
  password_confirmation: string
  organization_name: string
}

export interface LoginParams {
  email: string
  password: string
}

export interface TicketListParams {
  page?: number
  per_page?: number
  search?: string
  status?: string
  priority?: string
  category?: string
}
