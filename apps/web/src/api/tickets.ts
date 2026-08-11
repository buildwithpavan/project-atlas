import { get } from './client'
import type {
  DataEnvelope,
  PaginatedEnvelope,
  Ticket,
  TicketDetail,
  TicketListParams,
} from './types'

export function list(params: TicketListParams = {}): Promise<PaginatedEnvelope<Ticket>> {
  const query = new URLSearchParams()

  if (params.page !== undefined) query.set('page', String(params.page))
  if (params.per_page !== undefined) query.set('per_page', String(params.per_page))
  if (params.search) query.set('search', params.search)
  if (params.status) query.set('status', params.status)
  if (params.priority) query.set('priority', params.priority)
  if (params.category) query.set('category', params.category)

  const qs = query.toString()
  const path = qs ? `/tickets?${qs}` : '/tickets'

  return get<PaginatedEnvelope<Ticket>>(path)
}

export function getById(id: string): Promise<DataEnvelope<TicketDetail>> {
  return get<DataEnvelope<TicketDetail>>(`/tickets/${encodeURIComponent(id)}`)
}
