import { describe, it, expect, beforeEach, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { createRouter, createWebHistory } from 'vue-router'
import AskVoceivePage from '@/pages/AskVoceivePage.vue'
import * as conversationsApi from '@/api/conversations'
import { ApiError } from '@/api/errors'
import type { Conversation, AssistantMessage, DataEnvelope } from '@/api/types'

vi.mock('@/api/conversations')
vi.mock('@/api/auth', () => ({
  login: vi.fn(),
  register: vi.fn(),
  logout: vi.fn(),
  refresh: vi.fn(),
}))

const sampleConversation: Conversation = {
  id: 'conv-1',
  title: null,
  created_at: '2026-08-30T10:00:00Z',
  updated_at: '2026-08-30T10:00:00Z',
}

const sampleAssistantResponse: AssistantMessage = {
  id: 'msg-2',
  role: 'assistant',
  content: 'Based on your knowledge base, customers frequently mention refund processing times as a concern. The most common complaints relate to delays exceeding the stated 30-day policy.',
  position: 1,
  citations: [
    {
      chunk_id: 'chunk-1',
      document_id: 'doc-1',
      document_title: 'Refund Policy',
      content_preview: 'Our refund policy allows returns within 30 days...',
      similarity: 0.87,
      metadata: {},
    },
  ],
  has_sources: true,
  model: 'gpt-4o',
  prompt_tokens: 500,
  completion_tokens: 80,
  embedding_tokens: 10,
  retrieval_count: 3,
  retrieval_max_similarity: 0.87,
  latency_ms: 2500,
  created_at: '2026-08-30T10:00:05Z',
}

function setupMocks() {
  vi.mocked(conversationsApi.create).mockResolvedValue({
    data: sampleConversation,
  })
  vi.mocked(conversationsApi.sendMessage).mockResolvedValue({
    data: sampleAssistantResponse,
  })
}

function makeRouter() {
  return createRouter({
    history: createWebHistory(),
    routes: [
      { path: '/app/ask', name: 'ask-voceive', component: AskVoceivePage },
      { path: '/app/dashboard', name: 'dashboard', component: { template: '<div />' } },
    ],
  })
}

async function mountPage() {
  setupMocks()
  const pinia = createPinia()
  setActivePinia(pinia)
  const router = makeRouter()
  await router.push('/app/ask')
  await router.isReady()

  const wrapper = mount(AskVoceivePage, {
    global: { plugins: [pinia, router] },
  })
  await flushPromises()
  return wrapper
}

async function typeAndSend(wrapper: ReturnType<typeof mount>, text: string) {
  const textarea = wrapper.find('textarea')
  await textarea.setValue(text)
  await textarea.trigger('keydown', { key: 'Enter' })
  await flushPromises()
}

describe('AskVoceivePage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  // -- Page rendering -------------------------------------------------------

  it('renders the page header', async () => {
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('Ask Voceive')
  })

  it('renders the page description', async () => {
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('customer support knowledge')
  })

  it('renders the empty state', async () => {
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('Ask questions about your customer support data')
  })

  it('renders starter prompt suggestions', async () => {
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('What are customers saying about refunds?')
    expect(wrapper.text()).toContain('How should agents handle payment failures?')
  })

  it('renders the message input', async () => {
    const wrapper = await mountPage()
    const textarea = wrapper.find('textarea')
    expect(textarea.exists()).toBe(true)
    expect(textarea.attributes('placeholder')).toContain('Ask Voceive')
  })

  it('renders the send button', async () => {
    const wrapper = await mountPage()
    const sendBtn = wrapper.findAll('button').find((b) => b.text().trim() === 'Send')
    expect(sendBtn).toBeTruthy()
  })

  // -- Input validation -----------------------------------------------------

  it('disables send button when input is empty', async () => {
    const wrapper = await mountPage()
    const sendBtn = wrapper.findAll('button').find((b) => b.text().trim() === 'Send')!
    expect(sendBtn.attributes('disabled')).toBeDefined()
  })

  it('enables send button when input has text', async () => {
    const wrapper = await mountPage()
    const textarea = wrapper.find('textarea')
    await textarea.setValue('Hello')

    const sendBtn = wrapper.findAll('button').find((b) => b.text().trim() === 'Send')!
    expect(sendBtn.attributes('disabled')).toBeUndefined()
  })

  it('does not send whitespace-only messages', async () => {
    const wrapper = await mountPage()
    const textarea = wrapper.find('textarea')
    await textarea.setValue('   ')
    await textarea.trigger('keydown', { key: 'Enter' })
    await flushPromises()

    expect(conversationsApi.create).not.toHaveBeenCalled()
    expect(conversationsApi.sendMessage).not.toHaveBeenCalled()
  })

  it('does not send empty messages', async () => {
    const wrapper = await mountPage()
    const textarea = wrapper.find('textarea')
    await textarea.setValue('')
    await textarea.trigger('keydown', { key: 'Enter' })
    await flushPromises()

    expect(conversationsApi.create).not.toHaveBeenCalled()
  })

  // -- Sending messages -----------------------------------------------------

  it('creates a conversation on first message', async () => {
    const wrapper = await mountPage()
    await typeAndSend(wrapper, 'What is our refund policy?')

    expect(conversationsApi.create).toHaveBeenCalledTimes(1)
  })

  it('sends message to the correct conversation', async () => {
    const wrapper = await mountPage()
    await typeAndSend(wrapper, 'What is our refund policy?')

    expect(conversationsApi.sendMessage).toHaveBeenCalledWith('conv-1', 'What is our refund policy?')
  })

  it('sends message via Enter key', async () => {
    const wrapper = await mountPage()
    await typeAndSend(wrapper, 'Test question')

    expect(conversationsApi.sendMessage).toHaveBeenCalled()
  })

  it('sends message via Send button click', async () => {
    const wrapper = await mountPage()
    const textarea = wrapper.find('textarea')
    await textarea.setValue('Test question')

    const sendBtn = wrapper.findAll('button').find((b) => b.text().trim() === 'Send')!
    await sendBtn.trigger('click')
    await flushPromises()

    expect(conversationsApi.sendMessage).toHaveBeenCalled()
  })

  it('does not create a second conversation for subsequent messages', async () => {
    const wrapper = await mountPage()
    await typeAndSend(wrapper, 'First question')
    await typeAndSend(wrapper, 'Second question')

    expect(conversationsApi.create).toHaveBeenCalledTimes(1)
    expect(conversationsApi.sendMessage).toHaveBeenCalledTimes(2)
  })

  it('clears the input after sending', async () => {
    const wrapper = await mountPage()
    const textarea = wrapper.find('textarea')
    await textarea.setValue('Test question')
    await textarea.trigger('keydown', { key: 'Enter' })
    await flushPromises()

    expect((textarea.element as HTMLTextAreaElement).value).toBe('')
  })

  // -- Message rendering ----------------------------------------------------

  it('displays the user message', async () => {
    const wrapper = await mountPage()
    await typeAndSend(wrapper, 'What is our refund policy?')

    expect(wrapper.text()).toContain('What is our refund policy?')
  })

  it('displays the assistant response', async () => {
    const wrapper = await mountPage()
    await typeAndSend(wrapper, 'What is our refund policy?')

    expect(wrapper.text()).toContain('customers frequently mention refund processing times')
  })

  it('displays timestamps', async () => {
    const wrapper = await mountPage()
    await typeAndSend(wrapper, 'Hello')

    // The assistant message has a timestamp
    const timeElements = wrapper.findAll('.text-voceive-text-muted')
    const hasTimestamp = timeElements.some((el) => /\d{1,2}:\d{2}/.test(el.text()))
    expect(hasTimestamp).toBe(true)
  })

  it('renders multiple messages in order', async () => {
    const wrapper = await mountPage()
    await typeAndSend(wrapper, 'First question')

    vi.mocked(conversationsApi.sendMessage).mockResolvedValue({
      data: {
        ...sampleAssistantResponse,
        id: 'msg-4',
        content: 'Second answer',
        position: 3,
      },
    })
    await typeAndSend(wrapper, 'Second question')

    const text = wrapper.text()
    const firstIdx = text.indexOf('First question')
    const secondIdx = text.indexOf('Second question')
    expect(firstIdx).toBeLessThan(secondIdx)
  })

  it('renders user and assistant messages with different styling', async () => {
    const wrapper = await mountPage()
    await typeAndSend(wrapper, 'Hello')

    // User message has brand background
    const userBubble = wrapper.find('.bg-voceive-brand.text-white')
    expect(userBubble.exists()).toBe(true)

    // Assistant message has surface background with border
    const assistantBubble = wrapper.find('.bg-voceive-surface.border.border-voceive-border')
    expect(assistantBubble.exists()).toBe(true)
  })

  // -- Loading state --------------------------------------------------------

  it('shows thinking indicator while waiting for response', async () => {
    const wrapper = await mountPage()
    vi.mocked(conversationsApi.sendMessage).mockReturnValue(new Promise(() => {}) as any)

    const textarea = wrapper.find('textarea')
    await textarea.setValue('Test')
    await textarea.trigger('keydown', { key: 'Enter' })
    await wrapper.vm.$nextTick()

    expect(wrapper.text()).toContain('Thinking')
  })

  it('disables textarea while sending', async () => {
    const wrapper = await mountPage()
    vi.mocked(conversationsApi.sendMessage).mockReturnValue(new Promise(() => {}) as any)

    const textarea = wrapper.find('textarea')
    await textarea.setValue('Test')
    await textarea.trigger('keydown', { key: 'Enter' })
    await wrapper.vm.$nextTick()

    expect(textarea.attributes('disabled')).toBeDefined()
  })

  it('prevents duplicate submissions', async () => {
    const wrapper = await mountPage()
    vi.mocked(conversationsApi.sendMessage).mockReturnValue(new Promise(() => {}) as any)

    const textarea = wrapper.find('textarea')
    await textarea.setValue('Test')
    await textarea.trigger('keydown', { key: 'Enter' })
    await wrapper.vm.$nextTick()

    // Try to send again while waiting
    await textarea.setValue('Another')
    await textarea.trigger('keydown', { key: 'Enter' })
    await wrapper.vm.$nextTick()

    // Only one send call (the second was blocked by guard)
    expect(conversationsApi.sendMessage).toHaveBeenCalledTimes(1)
  })

  it('hides empty state after first message', async () => {
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('Ask questions about your customer support data')

    await typeAndSend(wrapper, 'Hello')

    expect(wrapper.text()).not.toContain('Ask questions about your customer support data')
  })

  // -- Starter prompts ------------------------------------------------------

  it('populates input when starter prompt is clicked', async () => {
    const wrapper = await mountPage()
    const promptBtns = wrapper.findAll('button').filter((b) =>
      b.text().includes('What are customers saying'),
    )
    expect(promptBtns.length).toBeGreaterThan(0)

    await promptBtns[0].trigger('click')

    const textarea = wrapper.find('textarea')
    expect((textarea.element as HTMLTextAreaElement).value).toContain('What are customers saying')
  })

  // -- Error handling -------------------------------------------------------

  it('shows error on API failure', async () => {
    const wrapper = await mountPage()
    vi.mocked(conversationsApi.sendMessage).mockRejectedValue(new Error('Network error'))

    await typeAndSend(wrapper, 'Test')

    expect(wrapper.text()).toContain('Something went wrong')
  })

  it('shows quota exceeded error', async () => {
    const wrapper = await mountPage()
    vi.mocked(conversationsApi.sendMessage).mockRejectedValue(
      new ApiError({
        type: '/errors/ai-quota-exceeded',
        title: 'AI Quota Exceeded',
        status: 429,
        detail: 'Your organization has exceeded its AI usage limit.',
      }),
    )

    await typeAndSend(wrapper, 'Test')

    expect(wrapper.text()).toContain('AI usage limit')
  })

  it('shows AI processing error', async () => {
    const wrapper = await mountPage()
    vi.mocked(conversationsApi.sendMessage).mockRejectedValue(
      new ApiError({
        type: '/errors/ai-processing',
        title: 'AI Processing Error',
        status: 500,
        detail: 'An error occurred while processing your request with the AI service.',
      }),
    )

    await typeAndSend(wrapper, 'Test')

    expect(wrapper.text()).toContain('error occurred while processing')
  })

  it('shows API error detail for other errors', async () => {
    const wrapper = await mountPage()
    vi.mocked(conversationsApi.sendMessage).mockRejectedValue(
      new ApiError({
        type: '/errors/validation',
        title: 'Validation Error',
        status: 422,
        detail: 'Content is too long',
      }),
    )

    await typeAndSend(wrapper, 'Test')

    expect(wrapper.text()).toContain('Content is too long')
  })

  it('dismisses error on dismiss click', async () => {
    const wrapper = await mountPage()
    vi.mocked(conversationsApi.sendMessage).mockRejectedValue(new Error('fail'))

    await typeAndSend(wrapper, 'Test')
    expect(wrapper.text()).toContain('Something went wrong')

    const dismissBtn = wrapper.findAll('button').find((b) => b.text().includes('Dismiss'))!
    await dismissBtn.trigger('click')
    await flushPromises()

    expect(wrapper.text()).not.toContain('Something went wrong')
  })

  it('re-enables input after error', async () => {
    const wrapper = await mountPage()
    vi.mocked(conversationsApi.sendMessage).mockRejectedValue(new Error('fail'))

    await typeAndSend(wrapper, 'Test')

    const textarea = wrapper.find('textarea')
    expect(textarea.attributes('disabled')).toBeUndefined()
  })

  it('handles conversation creation failure', async () => {
    const wrapper = await mountPage()
    vi.mocked(conversationsApi.create).mockRejectedValue(new Error('Failed to create'))

    await typeAndSend(wrapper, 'Test')

    expect(wrapper.text()).toContain('Something went wrong')
    expect(conversationsApi.sendMessage).not.toHaveBeenCalled()
  })

  // -- Keyboard interaction -------------------------------------------------

  it('allows Shift+Enter for newlines', async () => {
    const wrapper = await mountPage()
    const textarea = wrapper.find('textarea')
    await textarea.setValue('Line 1')
    await textarea.trigger('keydown', { key: 'Enter', shiftKey: true })
    await flushPromises()

    // Should NOT have sent the message
    expect(conversationsApi.create).not.toHaveBeenCalled()
  })

  // -- Safe rendering -------------------------------------------------------

  it('renders AI response as plain text (no HTML injection)', async () => {
    const wrapper = await mountPage()
    vi.mocked(conversationsApi.sendMessage).mockResolvedValue({
      data: {
        ...sampleAssistantResponse,
        content: '<script>alert("xss")</script>Injected',
      },
    })

    await typeAndSend(wrapper, 'Test')

    // The raw HTML should be escaped, not executed — check via wrapper.html()
    const html = wrapper.html()
    expect(html).toContain('&lt;script&gt;')
    expect(html).toContain('Injected')
  })

  // -- Accessibility --------------------------------------------------------

  it('has an accessible label on the message input', async () => {
    const wrapper = await mountPage()
    const textarea = wrapper.find('textarea')
    expect(textarea.attributes('aria-label')).toBe('Message input')
  })

  it('has role=alert on error messages', async () => {
    const wrapper = await mountPage()
    vi.mocked(conversationsApi.sendMessage).mockRejectedValue(new Error('fail'))

    await typeAndSend(wrapper, 'Test')

    const alert = wrapper.find('[role="alert"]')
    expect(alert.exists()).toBe(true)
  })
})
