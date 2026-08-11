import { get, post } from './client'
import type { DataEnvelope, Report, ExecutiveSummary } from './types'

export function getReport(): Promise<DataEnvelope<Report>> {
  return get<DataEnvelope<Report>>('/reports')
}

export function getExecutiveSummary(): Promise<DataEnvelope<ExecutiveSummary>> {
  return get<DataEnvelope<ExecutiveSummary>>('/reports/executive-summary')
}

export function generateExecutiveSummary(): Promise<DataEnvelope<ExecutiveSummary>> {
  return post<DataEnvelope<ExecutiveSummary>>('/reports/executive-summary')
}
