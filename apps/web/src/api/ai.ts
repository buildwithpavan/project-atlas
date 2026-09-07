import { get } from './client'
import type { DataEnvelope, AiQuota, AiUsage } from './types'

export function getQuota(): Promise<DataEnvelope<AiQuota>> {
  return get<DataEnvelope<AiQuota>>('/ai/quota')
}

export interface AiUsageParams {
  period?: string
  start_date?: string
  end_date?: string
}

export function getUsage(params?: AiUsageParams): Promise<DataEnvelope<AiUsage>> {
  const searchParams = new URLSearchParams()
  if (params?.period) searchParams.set('period', params.period)
  if (params?.start_date) searchParams.set('start_date', params.start_date)
  if (params?.end_date) searchParams.set('end_date', params.end_date)

  const qs = searchParams.toString()
  return get<DataEnvelope<AiUsage>>(`/ai/usage${qs ? `?${qs}` : ''}`)
}
