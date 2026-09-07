import { get, post } from './client'
import type {
  DataEnvelope,
  PaginatedEnvelope,
  Conversation,
  ConversationDetail,
  AssistantMessage,
} from './types'

export function list(page = 1, perPage = 25): Promise<PaginatedEnvelope<Conversation>> {
  return get<PaginatedEnvelope<Conversation>>(
    `/conversations?page=${page}&per_page=${perPage}`,
  )
}

export function create(title?: string): Promise<DataEnvelope<Conversation>> {
  return post<DataEnvelope<Conversation>>('/conversations', {
    conversation: { title: title ?? null },
  })
}

export function getById(id: string): Promise<DataEnvelope<ConversationDetail>> {
  return get<DataEnvelope<ConversationDetail>>(`/conversations/${encodeURIComponent(id)}`)
}

export function sendMessage(
  conversationId: string,
  content: string,
): Promise<DataEnvelope<AssistantMessage>> {
  return post<DataEnvelope<AssistantMessage>>(
    `/conversations/${encodeURIComponent(conversationId)}/messages`,
    { message: { content } },
    { timeout: 120_000 },
  )
}
