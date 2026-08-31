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

// -- Executive Summary ------------------------------------------------------

export interface KeyFinding {
  title: string
  description: string
  evidence_count: number
  category?: string | null
}

export interface AttentionItem {
  title: string
  description: string
  priority: 'high' | 'medium' | 'low'
  evidence_count: number
}

export interface RecommendedAction {
  title: string
  description: string
  evidence_count: number
}

export interface ExecutiveSummary {
  id: string
  summary: string
  key_findings: KeyFinding[]
  attention_items: AttentionItem[]
  recommended_actions: RecommendedAction[]
  analyzed_ticket_count: number
  generated_at: string
  stale: boolean
}

// -- API envelope wrappers --------------------------------------------------

export interface DataEnvelope<T> {
  data: T
}

export interface ListEnvelope<T> {
  data: T[]
  meta: { total: number }
}

export interface PaginatedEnvelope<T> {
  data: T[]
  meta: PaginationMeta
}

// -- Themes -----------------------------------------------------------------

export type ThemeSeverity = 'low' | 'medium' | 'high' | 'critical'
export type ThemeStatus = 'active' | 'resolved' | 'archived'

export interface Theme {
  id: string
  title: string
  description: string
  status: ThemeStatus
  severity: ThemeSeverity
  ticket_count: number
  evidence_summary: string | null
  recommended_action: string | null
  first_seen_at: string | null
  last_seen_at: string | null
  created_at: string
}

export interface ThemeTicket {
  id: string
  subject: string
  customer_name: string | null
  priority: string | null
  status: string | null
  relevance_score: number | null
  evidence_text: string | null
  created_at: string
}

export interface ThemeDetail extends Theme {
  tickets: ThemeTicket[]
}

export interface ThemeListParams {
  status?: string
  severity?: string
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

// -- Documents --------------------------------------------------------------

export type DocumentStatus = 'pending' | 'processing' | 'completed' | 'failed'

export interface DocumentUploader {
  id: string
  email: string
  first_name: string
  last_name: string
}

export interface Document {
  id: string
  title: string
  filename: string
  content_type: string
  file_size: number
  status: DocumentStatus
  error_message: string | null
  checksum: string | null
  chunk_count: number
  uploaded_by: DocumentUploader | null
  created_at: string
  updated_at: string
}

export interface DocumentListParams {
  page?: number
  per_page?: number
}

// -- Document Search --------------------------------------------------------

export interface DocumentSearchResult {
  chunk_id: string
  document_id: string
  document_title: string
  content: string
  similarity: number
  position: number
  metadata: Record<string, unknown>
}

export interface DocumentSearchMeta {
  query: string
  count: number
}

export interface DocumentSearchResponse {
  data: DocumentSearchResult[]
  meta: DocumentSearchMeta
}

// -- Conversations ----------------------------------------------------------

export interface Conversation {
  id: string
  title: string | null
  created_at: string
  updated_at: string
}

export interface ConversationMessage {
  id: string
  role: 'user' | 'assistant'
  content: string
  position: number
  created_at: string
}

export interface Citation {
  chunk_id: string
  document_id: string
  document_title: string
  content_preview: string
  similarity: number
  metadata: Record<string, unknown>
}

export interface AssistantMessage extends ConversationMessage {
  role: 'assistant'
  citations: Citation[]
  has_sources: boolean
  model: string
  prompt_tokens: number
  completion_tokens: number
  embedding_tokens: number
  retrieval_count: number
  retrieval_max_similarity: number | null
  latency_ms: number
}

export interface ConversationDetail extends Conversation {
  messages: (ConversationMessage | AssistantMessage)[]
}

// -- AI Quota ---------------------------------------------------------------

export interface AiQuotaCurrentMonth {
  tokens_used: number
  cost_used: number
  tokens_remaining: number | null
  cost_remaining: number | null
  token_percentage_used: number | null
  cost_percentage_used: number | null
}

export interface AiQuota {
  ai_monthly_token_limit: number | null
  ai_monthly_cost_limit: number | null
  ai_quota_reserved_tokens: number
  period: string
  current_month: AiQuotaCurrentMonth
}

// -- AI Usage ---------------------------------------------------------------

export interface AiUsageTokens {
  used: number
  limit: number | null
  remaining: number | null
  percentage_used: number | null
}

export interface AiUsageCost {
  used: number
  limit: number | null
  remaining: number | null
  percentage_used: number | null
}

export interface AiUsageByOperation {
  operation: string
  total_tokens: number
  prompt_tokens: number
  completion_tokens: number
  estimated_cost: number
  request_count: number
  average_latency_ms: number
}

export interface AiUsageByModel {
  model: string
  total_tokens: number
  estimated_cost: number
  request_count: number
}

export interface AiUsageByUser {
  user_id: string
  email: string
  total_tokens: number
  estimated_cost: number
  request_count: number
}

export interface AiUsageByDay {
  date: string
  total_tokens: number
  estimated_cost: number
  request_count: number
}

export interface AiUsage {
  period: string
  tokens: AiUsageTokens
  cost: AiUsageCost
  prompt_tokens: number
  completion_tokens: number
  request_count: number
  average_latency_ms: number
  by_operation: AiUsageByOperation[]
  by_model: AiUsageByModel[]
  by_user: AiUsageByUser[]
  by_day: AiUsageByDay[]
}
