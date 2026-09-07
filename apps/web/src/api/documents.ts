import { get, post, del } from './client'
import type {
  DataEnvelope,
  PaginatedEnvelope,
  Document,
  DocumentListParams,
  DocumentSearchResponse,
} from './types'

export function list(params: DocumentListParams = {}): Promise<PaginatedEnvelope<Document>> {
  const query = new URLSearchParams()

  if (params.page) query.set('page', String(params.page))
  if (params.per_page) query.set('per_page', String(params.per_page))

  const qs = query.toString()
  const path = qs ? `/documents?${qs}` : '/documents'

  return get<PaginatedEnvelope<Document>>(path)
}

export function getById(id: string): Promise<DataEnvelope<Document>> {
  return get<DataEnvelope<Document>>(`/documents/${encodeURIComponent(id)}`)
}

export function create(file: File, title?: string): Promise<DataEnvelope<Document>> {
  const form = new FormData()
  form.append('file', file)
  if (title) form.append('title', title)
  return post<DataEnvelope<Document>>('/documents', form)
}

export function destroy(id: string): Promise<void> {
  return del(`/documents/${encodeURIComponent(id)}`)
}

export function reprocess(id: string): Promise<DataEnvelope<Document>> {
  return post<DataEnvelope<Document>>(`/documents/${encodeURIComponent(id)}/reprocess`, {})
}

export function search(query: string): Promise<DocumentSearchResponse> {
  const qs = new URLSearchParams({ query }).toString()
  return get<DocumentSearchResponse>(`/documents/search?${qs}`)
}
