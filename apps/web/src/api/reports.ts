import { get } from './client'
import type { DataEnvelope, Report } from './types'

export function getReport(): Promise<DataEnvelope<Report>> {
  return get<DataEnvelope<Report>>('/reports')
}
