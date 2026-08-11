import { get } from './client'
import type { Dashboard, DataEnvelope } from './types'

export function getDashboard(): Promise<DataEnvelope<Dashboard>> {
  return get<DataEnvelope<Dashboard>>('/dashboard')
}
