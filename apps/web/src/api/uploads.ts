import { post } from './client'
import type { DataEnvelope, Upload } from './types'

export function create(file: File): Promise<DataEnvelope<Upload>> {
  const form = new FormData()
  form.append('file', file)
  return post<DataEnvelope<Upload>>('/uploads', form)
}
