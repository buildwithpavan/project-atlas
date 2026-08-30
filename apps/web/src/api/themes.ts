import { get, post } from './client'
import type {
  DataEnvelope,
  ListEnvelope,
  Theme,
  ThemeDetail,
  ThemeListParams,
} from './types'

export function list(params: ThemeListParams = {}): Promise<ListEnvelope<Theme>> {
  const query = new URLSearchParams()

  if (params.status) query.set('status', params.status)
  if (params.severity) query.set('severity', params.severity)

  const qs = query.toString()
  const path = qs ? `/themes?${qs}` : '/themes'

  return get<ListEnvelope<Theme>>(path)
}

export function getById(id: string): Promise<DataEnvelope<ThemeDetail>> {
  return get<DataEnvelope<ThemeDetail>>(`/themes/${encodeURIComponent(id)}`)
}

export function detect(): Promise<DataEnvelope<{ message: string }>> {
  return post<DataEnvelope<{ message: string }>>('/themes/detect', {})
}
