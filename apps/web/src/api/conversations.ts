import { get, post } from './client'
import type {
  DataEnvelope,
  Conversation,
  ConversationDetail,
  AssistantMessage,
} from './types'

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
