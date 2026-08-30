<script setup lang="ts">
import { ref, nextTick, computed } from 'vue'
import * as conversationsApi from '@/api/conversations'
import { ApiError } from '@/api/errors'
import type { ConversationMessage, AssistantMessage } from '@/api/types'
import { AButton } from '@/components/ui'

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

const conversationId = ref<string | null>(null)
const messages = ref<ConversationMessage[]>([])
const inputText = ref('')
const sending = ref(false)
const error = ref<string | null>(null)
const messagesContainer = ref<HTMLElement | null>(null)
const textareaRef = ref<HTMLTextAreaElement | null>(null)

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
    }

    const res = await conversationsApi.sendMessage(conversationId.value, content)
    const assistant: AssistantMessage = res.data

    // Add assistant response
    messages.value.push({
      id: assistant.id,
      role: 'assistant',
      content: assistant.content,
      position: assistant.position,
      created_at: assistant.created_at,
    })
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
</script>

<template>
  <div class="flex flex-col h-[calc(100vh-4rem)]">
    <!-- Header -->
    <div class="flex-shrink-0 border-b border-voceive-border px-4 py-4 sm:px-6">
      <h1 class="text-2xl font-bold text-voceive-text-primary">Ask Voceive</h1>
      <p class="mt-1 text-sm text-voceive-text-secondary">
        Ask questions about your customer support knowledge and discover insights.
      </p>
    </div>

    <!-- Messages area -->
    <div
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
  </div>
</template>
