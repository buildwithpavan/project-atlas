<script setup lang="ts">
import { ref, nextTick, computed, watch, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import * as conversationsApi from '@/api/conversations'
import { ApiError } from '@/api/errors'
import type { Conversation, ConversationMessage, AssistantMessage } from '@/api/types'
import { ABadge, AButton } from '@/components/ui'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type ChatMessage = ConversationMessage | AssistantMessage

function isAssistantWithCitations(msg: ChatMessage): msg is AssistantMessage {
  return msg.role === 'assistant' && 'citations' in msg && Array.isArray((msg as AssistantMessage).citations)
}

// ---------------------------------------------------------------------------
// Routing
// ---------------------------------------------------------------------------

const route = useRoute()
const router = useRouter()

// ---------------------------------------------------------------------------
// State — conversation history
// ---------------------------------------------------------------------------

const conversations = ref<Conversation[]>([])
const historyLoading = ref(false)
const historyError = ref<string | null>(null)
const historyOpen = ref(false)

// ---------------------------------------------------------------------------
// State — active conversation
// ---------------------------------------------------------------------------

const conversationId = ref<string | null>(null)
const messages = ref<ChatMessage[]>([])
const inputText = ref('')
const sending = ref(false)
const error = ref<string | null>(null)
const messagesContainer = ref<HTMLElement | null>(null)
const textareaRef = ref<HTMLTextAreaElement | null>(null)
const conversationLoading = ref(false)
const loadingConversationId = ref<string | null>(null)

const canSend = computed(() => inputText.value.trim().length > 0 && !sending.value)

// ---------------------------------------------------------------------------
// Scrolling
// ---------------------------------------------------------------------------

function scrollToBottom() {
  nextTick(() => {
    if (messagesContainer.value) {
      messagesContainer.value.scrollTop = messagesContainer.value.scrollHeight
    }
  })
}

// ---------------------------------------------------------------------------
// Conversation history
// ---------------------------------------------------------------------------

async function loadHistory() {
  historyLoading.value = true
  historyError.value = null
  try {
    const res = await conversationsApi.list()
    conversations.value = res.data
  } catch {
    historyError.value = 'Failed to load conversations.'
  } finally {
    historyLoading.value = false
  }
}

// ---------------------------------------------------------------------------
// Load a specific conversation
// ---------------------------------------------------------------------------

async function loadConversation(id: string) {
  // Guard against stale responses
  loadingConversationId.value = id
  conversationLoading.value = true
  error.value = null

  try {
    const res = await conversationsApi.getById(id)
    // Stale response guard
    if (loadingConversationId.value !== id) return

    conversationId.value = id
    messages.value = res.data.messages
    scrollToBottom()

    // Update route if needed
    if (route.params.conversationId !== id) {
      router.replace({ name: 'ask-voceive-conversation', params: { conversationId: id } })
    }
  } catch (err: unknown) {
    if (loadingConversationId.value !== id) return
    if (err instanceof ApiError && err.status === 404) {
      error.value = 'Conversation not found.'
      router.replace({ name: 'ask-voceive' })
    } else {
      error.value = 'Failed to load conversation.'
    }
  } finally {
    if (loadingConversationId.value === id) {
      conversationLoading.value = false
      loadingConversationId.value = null
    }
  }
}

function selectConversation(id: string) {
  historyOpen.value = false
  loadConversation(id)
}

function startNewConversation() {
  conversationId.value = null
  messages.value = []
  error.value = null
  historyOpen.value = false
  router.replace({ name: 'ask-voceive' })
  nextTick(() => textareaRef.value?.focus())
}

// ---------------------------------------------------------------------------
// Conversation list display
// ---------------------------------------------------------------------------

function conversationLabel(conv: Conversation): string {
  return conv.title || 'New conversation'
}

function formatDate(dateStr: string): string {
  const d = new Date(dateStr)
  const now = new Date()
  const diffMs = now.getTime() - d.getTime()
  const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24))
  if (diffDays === 0) return 'Today'
  if (diffDays === 1) return 'Yesterday'
  if (diffDays < 7) return `${diffDays} days ago`
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
}

// ---------------------------------------------------------------------------
// Conversation creation + message sending
// ---------------------------------------------------------------------------

async function handleSend() {
  const content = inputText.value.trim()
  if (!content || sending.value) return

  sending.value = true
  error.value = null
  inputText.value = ''

  // Add user message optimistically
  const userMessage: ConversationMessage = {
    id: `temp-${Date.now()}`,
    role: 'user',
    content,
    position: messages.value.length,
    created_at: new Date().toISOString(),
  }
  messages.value.push(userMessage)
  scrollToBottom()

  try {
    // Create conversation lazily on first message
    if (!conversationId.value) {
      const convRes = await conversationsApi.create()
      conversationId.value = convRes.data.id

      // Add to history list and update route
      conversations.value.unshift(convRes.data)
      router.replace({ name: 'ask-voceive-conversation', params: { conversationId: convRes.data.id } })
    }

    const res = await conversationsApi.sendMessage(conversationId.value, content)

    // Store the full assistant message including citations
    messages.value.push(res.data)
    scrollToBottom()
  } catch (err: unknown) {
    if (err instanceof ApiError) {
      if (err.status === 429) {
        error.value = 'You\u2019ve reached your AI usage limit. Please try again later or contact your administrator.'
      } else if (err.type === '/errors/ai-processing') {
        error.value = 'An error occurred while processing your request. Please try again.'
      } else {
        error.value = err.detail
      }
    } else {
      error.value = 'Something went wrong. Please try again.'
    }
  } finally {
    sending.value = false
    nextTick(() => textareaRef.value?.focus())
  }
}

function handleKeydown(e: KeyboardEvent) {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault()
    handleSend()
  }
}

function dismissError() {
  error.value = null
}

// ---------------------------------------------------------------------------
// Formatting
// ---------------------------------------------------------------------------

function formatTime(dateStr: string): string {
  return new Date(dateStr).toLocaleTimeString('en-US', {
    hour: 'numeric',
    minute: '2-digit',
  })
}

// ---------------------------------------------------------------------------
// Relevance — same thresholds as Knowledge Base search
// ---------------------------------------------------------------------------

function relevanceLabel(similarity: number): { text: string; variant: 'success' | 'info' | 'warning' | 'default' } {
  if (similarity >= 0.8) return { text: 'High relevance', variant: 'success' }
  if (similarity >= 0.6) return { text: 'Good relevance', variant: 'info' }
  if (similarity >= 0.4) return { text: 'Moderate relevance', variant: 'warning' }
  return { text: 'Low relevance', variant: 'default' }
}

// ---------------------------------------------------------------------------
// Initialization
// ---------------------------------------------------------------------------

onMounted(async () => {
  loadHistory()

  const paramId = route.params.conversationId as string | undefined
  if (paramId) {
    loadConversation(paramId)
  }
})

watch(() => route.params.conversationId, (newId) => {
  const id = newId as string | undefined
  if (id && id !== conversationId.value) {
    loadConversation(id)
  } else if (!id && conversationId.value) {
    // Only clear state when navigating away from an active conversation
    conversationId.value = null
    messages.value = []
  }
})
</script>

<template>
  <div class="flex h-[calc(100vh-4rem)]">
    <!-- Mobile history backdrop -->
    <div
      v-if="historyOpen"
      class="fixed inset-0 z-20 bg-black/30 lg:hidden"
      @click="historyOpen = false"
    />

    <!-- Conversation history sidebar -->
    <aside
      class="fixed inset-y-0 left-0 z-30 w-72 flex flex-col border-r border-voceive-border bg-voceive-surface transition-transform lg:static lg:translate-x-0 lg:z-auto"
      :class="historyOpen ? 'translate-x-0' : '-translate-x-full'"
      aria-label="Conversation history"
    >
      <!-- Sidebar header -->
      <div class="flex-shrink-0 flex items-center justify-between border-b border-voceive-border px-4 py-3">
        <h2 class="text-sm font-semibold text-voceive-text-primary">History</h2>
        <div class="flex items-center gap-1">
          <button
            type="button"
            class="voceive-focus-ring rounded-voceive p-1.5 text-voceive-text-secondary hover:bg-voceive-surface-muted hover:text-voceive-text-primary transition-colors"
            aria-label="New conversation"
            @click="startNewConversation"
          >
            <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
            </svg>
          </button>
          <button
            type="button"
            class="voceive-focus-ring rounded-voceive p-1.5 text-voceive-text-secondary hover:bg-voceive-surface-muted hover:text-voceive-text-primary transition-colors lg:hidden"
            aria-label="Close history"
            @click="historyOpen = false"
          >
            <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
      </div>

      <!-- Sidebar content -->
      <div class="flex-1 overflow-y-auto">
        <!-- Loading -->
        <div v-if="historyLoading" class="px-4 py-6 text-center">
          <div class="flex items-center justify-center gap-2 text-sm text-voceive-text-muted">
            <svg class="animate-spin size-4" viewBox="0 0 24 24" fill="none" aria-hidden="true">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
            </svg>
            <span>Loading…</span>
          </div>
        </div>

        <!-- Error -->
        <div v-else-if="historyError" class="px-4 py-6 text-center">
          <p class="text-sm text-voceive-error mb-2">{{ historyError }}</p>
          <button
            type="button"
            class="text-sm font-medium text-voceive-brand hover:underline"
            @click="loadHistory"
          >
            Retry
          </button>
        </div>

        <!-- Empty -->
        <div v-else-if="conversations.length === 0" class="px-4 py-6 text-center">
          <p class="text-sm text-voceive-text-muted">No conversations yet.</p>
          <p class="mt-1 text-xs text-voceive-text-muted">Start a conversation to explore your support knowledge.</p>
        </div>

        <!-- Conversation list -->
        <nav v-else class="px-2 py-2 space-y-0.5" aria-label="Conversations">
          <button
            v-for="conv in conversations"
            :key="conv.id"
            type="button"
            class="voceive-focus-ring w-full text-left rounded-voceive px-3 py-2.5 transition-colors"
            :class="conv.id === conversationId
              ? 'bg-voceive-brand-subtle text-voceive-brand'
              : 'text-voceive-text-secondary hover:bg-voceive-surface-muted hover:text-voceive-text-primary'"
            :aria-current="conv.id === conversationId ? 'true' : undefined"
            @click="selectConversation(conv.id)"
          >
            <p class="text-sm font-medium truncate">{{ conversationLabel(conv) }}</p>
            <p class="text-xs mt-0.5 opacity-70 truncate">{{ formatDate(conv.updated_at) }}</p>
          </button>
        </nav>
      </div>
    </aside>

    <!-- Main chat area -->
    <div class="flex flex-1 flex-col min-w-0">
      <!-- Header -->
      <div class="flex-shrink-0 border-b border-voceive-border px-4 py-4 sm:px-6">
        <div class="flex items-center gap-3">
          <button
            type="button"
            class="voceive-focus-ring rounded-voceive p-1.5 text-voceive-text-secondary hover:bg-voceive-surface-muted lg:hidden"
            aria-label="Open conversation history"
            @click="historyOpen = true"
          >
            <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5" />
            </svg>
          </button>
          <div class="min-w-0">
            <h1 class="text-2xl font-bold text-voceive-text-primary">Ask Voceive</h1>
            <p class="mt-1 text-sm text-voceive-text-secondary">
              Ask questions about your customer support knowledge and discover insights.
            </p>
          </div>
        </div>
      </div>

      <!-- Conversation loading -->
      <div v-if="conversationLoading" class="flex-1 flex items-center justify-center">
        <div class="flex items-center gap-2 text-sm text-voceive-text-muted">
          <svg class="animate-spin size-5" viewBox="0 0 24 24" fill="none" aria-hidden="true">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
          </svg>
          <span>Loading conversation…</span>
        </div>
      </div>

      <!-- Messages area -->
      <div
        v-else
        ref="messagesContainer"
        class="flex-1 overflow-y-auto px-4 py-6 sm:px-6"
      >
      <!-- Empty state -->
      <div
        v-if="messages.length === 0 && !sending"
        class="flex items-center justify-center h-full"
      >
        <div class="text-center max-w-md">
          <div class="mx-auto mb-4 size-14 rounded-full bg-voceive-brand-subtle flex items-center justify-center">
            <svg
              class="size-7 text-voceive-brand"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M7.5 8.25h9m-9 3H12m-9.75 1.51c0 1.6 1.123 2.994 2.707 3.227 1.087.16 2.185.283 3.293.369V21l4.076-4.076a1.526 1.526 0 011.037-.443 48.282 48.282 0 005.68-.494c1.584-.233 2.707-1.626 2.707-3.228V6.741c0-1.602-1.123-2.995-2.707-3.228A48.394 48.394 0 0012 3c-2.392 0-4.744.175-7.043.513C3.373 3.746 2.25 5.14 2.25 6.741v6.018z"
              />
            </svg>
          </div>
          <h2 class="text-lg font-semibold text-voceive-text-primary">
            Ask Voceive
          </h2>
          <p class="mt-2 text-sm text-voceive-text-secondary">
            Ask questions about your customer support data, knowledge base documents, and organizational insights.
          </p>
          <div class="mt-6 flex flex-wrap justify-center gap-2">
            <button
              v-for="prompt in [
                'What are customers saying about refunds?',
                'What are the main support issues this month?',
                'How should agents handle payment failures?',
              ]"
              :key="prompt"
              type="button"
              class="rounded-voceive border border-voceive-border bg-voceive-surface px-3 py-2 text-xs text-voceive-text-secondary hover:border-voceive-brand hover:text-voceive-brand transition-colors text-left"
              @click="inputText = prompt"
            >
              {{ prompt }}
            </button>
          </div>
        </div>
      </div>

      <!-- Message list -->
      <div v-else class="space-y-6 max-w-3xl mx-auto">
        <div
          v-for="msg in messages"
          :key="msg.id"
          class="flex"
          :class="msg.role === 'user' ? 'justify-end' : 'justify-start'"
        >
          <!-- User message -->
          <div
            v-if="msg.role === 'user'"
            class="max-w-[80%] sm:max-w-[70%]"
          >
            <div class="rounded-voceive-md bg-voceive-brand text-white px-4 py-3">
              <p class="text-sm whitespace-pre-wrap">{{ msg.content }}</p>
            </div>
            <p class="mt-1 text-xs text-voceive-text-muted text-right">
              {{ formatTime(msg.created_at) }}
            </p>
          </div>

          <!-- Assistant message -->
          <div
            v-else
            class="max-w-[85%] sm:max-w-[75%]"
          >
            <div class="flex items-start gap-3">
              <div class="flex-shrink-0 mt-0.5 size-7 rounded-full bg-voceive-brand-subtle flex items-center justify-center">
                <svg
                  class="size-4 text-voceive-brand"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  aria-hidden="true"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.455 2.456L21.75 6l-1.036.259a3.375 3.375 0 00-2.455 2.456zM16.894 20.567L16.5 21.75l-.394-1.183a2.25 2.25 0 00-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 001.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 001.423 1.423l1.183.394-1.183.394a2.25 2.25 0 00-1.423 1.423z"
                  />
                </svg>
              </div>
              <div class="min-w-0 flex-1">
                <div class="rounded-voceive-md bg-voceive-surface border border-voceive-border px-4 py-3">
                  <p class="text-sm text-voceive-text-primary whitespace-pre-wrap">{{ msg.content }}</p>
                </div>

                <!-- Sources section -->
                <div
                  v-if="isAssistantWithCitations(msg) && msg.citations.length > 0"
                  class="mt-3"
                >
                  <p class="text-xs font-semibold text-voceive-text-secondary mb-2">Sources</p>
                  <div class="space-y-2">
                    <div
                      v-for="citation in msg.citations"
                      :key="citation.chunk_id"
                      class="rounded-voceive border border-voceive-border bg-voceive-background px-3 py-2.5"
                      role="article"
                      :aria-label="`Source: ${citation.document_title}`"
                    >
                      <div class="flex flex-wrap items-center gap-2 mb-1">
                        <span class="text-xs font-semibold text-voceive-text-primary">{{ citation.document_title }}</span>
                        <ABadge :variant="relevanceLabel(citation.similarity).variant">
                          {{ relevanceLabel(citation.similarity).text }}
                        </ABadge>
                      </div>
                      <p
                        v-if="citation.content_preview"
                        class="text-xs text-voceive-text-secondary leading-relaxed line-clamp-3"
                      >{{ citation.content_preview }}</p>
                      <div class="flex items-center gap-2 mt-1.5 text-xs text-voceive-text-muted">
                        <span v-if="citation.metadata && citation.metadata.section_title">{{ citation.metadata.section_title }}</span>
                        <span>{{ Math.round(citation.similarity * 100) }}% match</span>
                      </div>
                    </div>
                  </div>
                </div>

                <p class="mt-1 text-xs text-voceive-text-muted">
                  {{ formatTime(msg.created_at) }}
                </p>
              </div>
            </div>
          </div>
        </div>

        <!-- Thinking indicator -->
        <div v-if="sending" class="flex justify-start">
          <div class="flex items-start gap-3">
            <div class="flex-shrink-0 mt-0.5 size-7 rounded-full bg-voceive-brand-subtle flex items-center justify-center">
              <svg
                class="size-4 text-voceive-brand animate-pulse"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                aria-hidden="true"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.455 2.456L21.75 6l-1.036.259a3.375 3.375 0 00-2.455 2.456zM16.894 20.567L16.5 21.75l-.394-1.183a2.25 2.25 0 00-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 001.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 001.423 1.423l1.183.394-1.183.394a2.25 2.25 0 00-1.423 1.423z"
                />
              </svg>
            </div>
            <div class="rounded-voceive-md bg-voceive-surface border border-voceive-border px-4 py-3">
              <div class="flex items-center gap-2 text-sm text-voceive-text-muted">
                <svg class="animate-spin size-4" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                </svg>
                <span>Thinking…</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Error banner -->
    <div
      v-if="error"
      class="flex-shrink-0 border-t border-voceive-error/20 bg-voceive-error-subtle px-4 py-3 sm:px-6"
    >
      <div class="flex items-center justify-between max-w-3xl mx-auto">
        <p class="text-sm text-voceive-error" role="alert">{{ error }}</p>
        <button
          class="text-sm font-medium text-voceive-error underline hover:no-underline ml-4 flex-shrink-0"
          @click="dismissError"
        >
          Dismiss
        </button>
      </div>
    </div>

    <!-- Composer -->
    <div class="flex-shrink-0 border-t border-voceive-border bg-voceive-surface px-4 py-3 sm:px-6">
      <div class="flex items-end gap-3 max-w-3xl mx-auto">
        <textarea
          ref="textareaRef"
          v-model="inputText"
          placeholder="Ask Voceive something…"
          aria-label="Message input"
          rows="1"
          class="voceive-focus-ring flex-1 resize-none rounded-voceive border border-voceive-border bg-voceive-background px-3 py-2 text-sm text-voceive-text-primary placeholder:text-voceive-text-muted transition-colors hover:border-voceive-border-strong min-h-[2.5rem] max-h-32"
          :disabled="sending"
          @keydown="handleKeydown"
        />
        <AButton
          variant="primary"
          size="md"
          :disabled="!canSend"
          :loading="sending"
          @click="handleSend"
        >
          Send
        </AButton>
      </div>
    </div>
    </div><!-- /main chat area -->
  </div><!-- /outer flex row -->
</template>
