import { describe, it, expect, beforeEach, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { createRouter, createWebHistory } from 'vue-router'
import AskVoceivePage from '@/pages/AskVoceivePage.vue'
import * as conversationsApi from '@/api/conversations'
import { ApiError } from '@/api/errors'
import type { Conversation, AssistantMessage } from '@/api/types'

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
  vi.mocked(conversationsApi.list).mockResolvedValue({
    data: [],
    meta: { page: 1, per_page: 25, total: 0, total_pages: 0 },
  })
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
      { path: '/app/ask/:conversationId', name: 'ask-voceive-conversation', component: AskVoceivePage },
      { path: '/app/dashboard', name: 'dashboard', component: { template: '<div />' } },
    ],
  })
}

async function mountPage(opts?: { conversationId?: string }) {
  const pinia = createPinia()
  setActivePinia(pinia)
  const router = makeRouter()
  const path = opts?.conversationId ? `/app/ask/${opts.conversationId}` : '/app/ask'
  await router.push(path)
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
    setupMocks()
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

  // -- Citation rendering ---------------------------------------------------

  it('displays Sources section when assistant has citations', async () => {
    const wrapper = await mountPage()
    await typeAndSend(wrapper, 'Test')

    expect(wrapper.text()).toContain('Sources')
  })

  it('displays citation document title', async () => {
    const wrapper = await mountPage()
    await typeAndSend(wrapper, 'Test')

    expect(wrapper.text()).toContain('Refund Policy')
  })

  it('displays citation content preview', async () => {
    const wrapper = await mountPage()
    await typeAndSend(wrapper, 'Test')

    expect(wrapper.text()).toContain('Our refund policy allows returns within 30 days')
  })

  it('displays relevance badge for citation', async () => {
    const wrapper = await mountPage()
    await typeAndSend(wrapper, 'Test')

    // similarity 0.87 → "High relevance"
    expect(wrapper.text()).toContain('High relevance')
  })

  it('displays match percentage for citation', async () => {
    const wrapper = await mountPage()
    await typeAndSend(wrapper, 'Test')

    expect(wrapper.text()).toContain('87% match')
  })

  it('does not show Sources section when assistant has no citations', async () => {
    const wrapper = await mountPage()
    vi.mocked(conversationsApi.sendMessage).mockResolvedValue({
      data: {
        ...sampleAssistantResponse,
        citations: [],
        has_sources: false,
      },
    })

    await typeAndSend(wrapper, 'Test')

    expect(wrapper.text()).not.toContain('Sources')
  })

  it('renders multiple citations', async () => {
    const wrapper = await mountPage()
    vi.mocked(conversationsApi.sendMessage).mockResolvedValue({
      data: {
        ...sampleAssistantResponse,
        citations: [
          { chunk_id: 'chunk-1', document_id: 'doc-1', document_title: 'Refund Policy', content_preview: 'Our refund policy...', similarity: 0.87, metadata: {} },
          { chunk_id: 'chunk-2', document_id: 'doc-2', document_title: 'Shipping Guidelines', content_preview: 'All orders ship...', similarity: 0.72, metadata: { section_title: 'Domestic Shipping' } },
          { chunk_id: 'chunk-3', document_id: 'doc-3', document_title: 'FAQ Document', content_preview: 'Common questions...', similarity: 0.45, metadata: {} },
        ],
      },
    })

    await typeAndSend(wrapper, 'Test')

    expect(wrapper.text()).toContain('Refund Policy')
    expect(wrapper.text()).toContain('Shipping Guidelines')
    expect(wrapper.text()).toContain('FAQ Document')
  })

  it('preserves citation order from API', async () => {
    const wrapper = await mountPage()
    vi.mocked(conversationsApi.sendMessage).mockResolvedValue({
      data: {
        ...sampleAssistantResponse,
        citations: [
          { chunk_id: 'c1', document_id: 'd1', document_title: 'First Source', content_preview: '', similarity: 0.9, metadata: {} },
          { chunk_id: 'c2', document_id: 'd2', document_title: 'Second Source', content_preview: '', similarity: 0.7, metadata: {} },
        ],
      },
    })

    await typeAndSend(wrapper, 'Test')

    const text = wrapper.text()
    expect(text.indexOf('First Source')).toBeLessThan(text.indexOf('Second Source'))
  })

  it('displays correct relevance tiers', async () => {
    const wrapper = await mountPage()
    vi.mocked(conversationsApi.sendMessage).mockResolvedValue({
      data: {
        ...sampleAssistantResponse,
        citations: [
          { chunk_id: 'c1', document_id: 'd1', document_title: 'High', content_preview: '', similarity: 0.85, metadata: {} },
          { chunk_id: 'c2', document_id: 'd2', document_title: 'Good', content_preview: '', similarity: 0.65, metadata: {} },
          { chunk_id: 'c3', document_id: 'd3', document_title: 'Moderate', content_preview: '', similarity: 0.45, metadata: {} },
          { chunk_id: 'c4', document_id: 'd4', document_title: 'Low', content_preview: '', similarity: 0.35, metadata: {} },
        ],
      },
    })

    await typeAndSend(wrapper, 'Test')

    expect(wrapper.text()).toContain('High relevance')
    expect(wrapper.text()).toContain('Good relevance')
    expect(wrapper.text()).toContain('Moderate relevance')
    expect(wrapper.text()).toContain('Low relevance')
  })

  it('displays section title from metadata when present', async () => {
    const wrapper = await mountPage()
    vi.mocked(conversationsApi.sendMessage).mockResolvedValue({
      data: {
        ...sampleAssistantResponse,
        citations: [
          { chunk_id: 'c1', document_id: 'd1', document_title: 'Refund Policy', content_preview: 'Excerpt', similarity: 0.8, metadata: { section_title: 'Returns & Exchanges' } },
        ],
      },
    })

    await typeAndSend(wrapper, 'Test')

    expect(wrapper.text()).toContain('Returns & Exchanges')
  })

  it('source cards have accessible aria-label', async () => {
    const wrapper = await mountPage()
    await typeAndSend(wrapper, 'Test')

    const sourceCard = wrapper.find('[role="article"]')
    expect(sourceCard.exists()).toBe(true)
    expect(sourceCard.attributes('aria-label')).toBe('Source: Refund Policy')
  })

  it('renders citation content as plain text (no HTML injection)', async () => {
    const wrapper = await mountPage()
    vi.mocked(conversationsApi.sendMessage).mockResolvedValue({
      data: {
        ...sampleAssistantResponse,
        citations: [
          {
            chunk_id: 'xss', document_id: 'xss', document_title: '<img onerror="alert(1)" src="x">',
            content_preview: '<script>alert("xss")</script>Malicious', similarity: 0.9,
            metadata: { section_title: '<b>bold</b>' },
          },
        ],
      },
    })

    await typeAndSend(wrapper, 'Test')

    const html = wrapper.html()
    expect(html).toContain('&lt;script&gt;')
    expect(html).toContain('&lt;img onerror')
    expect(html).toContain('&lt;b&gt;bold&lt;/b&gt;')
    expect(wrapper.text()).toContain('Malicious')
  })

  it('does not show Sources during loading', async () => {
    const wrapper = await mountPage()
    vi.mocked(conversationsApi.sendMessage).mockReturnValue(new Promise(() => {}) as any)

    const textarea = wrapper.find('textarea')
    await textarea.setValue('Test')
    await textarea.trigger('keydown', { key: 'Enter' })
    await wrapper.vm.$nextTick()

    expect(wrapper.text()).toContain('Thinking')
    expect(wrapper.findAll('[role="article"]').length).toBe(0)
  })

  it('does not render citations on error', async () => {
    const wrapper = await mountPage()
    vi.mocked(conversationsApi.sendMessage).mockRejectedValue(new Error('fail'))

    await typeAndSend(wrapper, 'Test')

    expect(wrapper.text()).toContain('Something went wrong')
    expect(wrapper.findAll('[role="article"]').length).toBe(0)
  })

  it('handles citation with empty content_preview', async () => {
    const wrapper = await mountPage()
    vi.mocked(conversationsApi.sendMessage).mockResolvedValue({
      data: {
        ...sampleAssistantResponse,
        citations: [
          { chunk_id: 'c-empty', document_id: 'd-empty', document_title: 'Empty Preview Doc', content_preview: '', similarity: 0.75, metadata: {} },
        ],
      },
    })

    await typeAndSend(wrapper, 'Test')

    expect(wrapper.text()).toContain('Empty Preview Doc')
    expect(wrapper.text()).toContain('Good relevance')
  })

  // -- Conversation history -------------------------------------------------

  it('loads conversation list on mount', async () => {
    await mountPage()
    expect(conversationsApi.list).toHaveBeenCalledTimes(1)
  })

  it('renders conversation history sidebar', async () => {
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('History')
  })

  it('renders conversations in the history list', async () => {
    vi.mocked(conversationsApi.list).mockResolvedValue({
      data: [
        { id: 'c1', title: 'Refund inquiry', created_at: '2026-08-30T10:00:00Z', updated_at: '2026-08-30T10:00:00Z' },
        { id: 'c2', title: 'Shipping question', created_at: '2026-08-29T10:00:00Z', updated_at: '2026-08-29T10:00:00Z' },
      ],
      meta: { page: 1, per_page: 25, total: 2, total_pages: 1 },
    })
    const wrapper = await mountPage()

    expect(wrapper.text()).toContain('Refund inquiry')
    expect(wrapper.text()).toContain('Shipping question')
  })

  it('shows empty history message when no conversations', async () => {
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('No conversations yet')
  })

  it('shows loading state for history', async () => {
    vi.mocked(conversationsApi.list).mockReturnValue(new Promise(() => {}) as any)
    const wrapper = await mountPage()

    expect(wrapper.text()).toContain('Loading')
  })

  it('shows error state for history with retry', async () => {
    vi.mocked(conversationsApi.list).mockRejectedValue(new Error('Network error'))
    const wrapper = await mountPage()

    expect(wrapper.text()).toContain('Failed to load conversations')

    vi.mocked(conversationsApi.list).mockResolvedValue({
      data: [{ id: 'c1', title: 'Recovered', created_at: '2026-08-30T10:00:00Z', updated_at: '2026-08-30T10:00:00Z' }],
      meta: { page: 1, per_page: 25, total: 1, total_pages: 1 },
    })
    const retryBtn = wrapper.findAll('button').find((b) => b.text().includes('Retry'))!
    await retryBtn.trigger('click')
    await flushPromises()

    expect(wrapper.text()).toContain('Recovered')
  })

  it('shows fallback label for conversations without title', async () => {
    vi.mocked(conversationsApi.list).mockResolvedValue({
      data: [{ id: 'c1', title: null, created_at: '2026-08-30T10:00:00Z', updated_at: '2026-08-30T10:00:00Z' }],
      meta: { page: 1, per_page: 25, total: 1, total_pages: 1 },
    })
    const wrapper = await mountPage()

    expect(wrapper.text()).toContain('New conversation')
  })

  // -- Conversation selection -----------------------------------------------

  it('loads conversation when selected from history', async () => {
    vi.mocked(conversationsApi.list).mockResolvedValue({
      data: [{ id: 'c1', title: 'My chat', created_at: '2026-08-30T10:00:00Z', updated_at: '2026-08-30T10:00:00Z' }],
      meta: { page: 1, per_page: 25, total: 1, total_pages: 1 },
    })
    vi.mocked(conversationsApi.getById).mockResolvedValue({
      data: {
        id: 'c1', title: 'My chat', created_at: '2026-08-30T10:00:00Z', updated_at: '2026-08-30T10:00:00Z',
        messages: [
          { id: 'm1', role: 'user' as const, content: 'Hello', position: 0, created_at: '2026-08-30T10:00:00Z' },
          { id: 'm2', role: 'assistant' as const, content: 'Hi there!', position: 1, created_at: '2026-08-30T10:01:00Z' },
        ],
      },
    })
    const wrapper = await mountPage()

    const convBtn = wrapper.findAll('button').find((b) => b.text().includes('My chat'))!
    await convBtn.trigger('click')
    await flushPromises()

    expect(conversationsApi.getById).toHaveBeenCalledWith('c1')
    expect(wrapper.text()).toContain('Hello')
    expect(wrapper.text()).toContain('Hi there!')
  })

  it('highlights active conversation in history', async () => {
    vi.mocked(conversationsApi.list).mockResolvedValue({
      data: [{ id: 'c1', title: 'Active chat', created_at: '2026-08-30T10:00:00Z', updated_at: '2026-08-30T10:00:00Z' }],
      meta: { page: 1, per_page: 25, total: 1, total_pages: 1 },
    })
    vi.mocked(conversationsApi.getById).mockResolvedValue({
      data: {
        id: 'c1', title: 'Active chat', created_at: '2026-08-30T10:00:00Z', updated_at: '2026-08-30T10:00:00Z',
        messages: [{ id: 'm1', role: 'user' as const, content: 'Test', position: 0, created_at: '2026-08-30T10:00:00Z' }],
      },
    })
    const wrapper = await mountPage()

    const convBtn = wrapper.findAll('button').find((b) => b.text().includes('Active chat'))!
    await convBtn.trigger('click')
    await flushPromises()

    expect(convBtn.attributes('aria-current')).toBe('true')
  })

  it('preserves citations when loading existing conversation', async () => {
    vi.mocked(conversationsApi.list).mockResolvedValue({
      data: [{ id: 'c1', title: 'Chat', created_at: '2026-08-30T10:00:00Z', updated_at: '2026-08-30T10:00:00Z' }],
      meta: { page: 1, per_page: 25, total: 1, total_pages: 1 },
    })
    vi.mocked(conversationsApi.getById).mockResolvedValue({
      data: {
        id: 'c1', title: 'Chat', created_at: '2026-08-30T10:00:00Z', updated_at: '2026-08-30T10:00:00Z',
        messages: [
          { id: 'm1', role: 'user' as const, content: 'Question', position: 0, created_at: '2026-08-30T10:00:00Z' },
          { ...sampleAssistantResponse, id: 'm2', position: 1 },
        ],
      },
    })
    const wrapper = await mountPage()

    const convBtn = wrapper.findAll('button').find((b) => b.text().includes('Chat'))!
    await convBtn.trigger('click')
    await flushPromises()

    expect(wrapper.text()).toContain('Sources')
    expect(wrapper.text()).toContain('Refund Policy')
    expect(wrapper.text()).toContain('High relevance')
  })

  it('shows conversation loading state', async () => {
    vi.mocked(conversationsApi.list).mockResolvedValue({
      data: [{ id: 'c1', title: 'Chat', created_at: '2026-08-30T10:00:00Z', updated_at: '2026-08-30T10:00:00Z' }],
      meta: { page: 1, per_page: 25, total: 1, total_pages: 1 },
    })
    vi.mocked(conversationsApi.getById).mockReturnValue(new Promise(() => {}) as any)
    const wrapper = await mountPage()

    const convBtn = wrapper.findAll('button').find((b) => b.text().includes('Chat'))!
    await convBtn.trigger('click')
    await wrapper.vm.$nextTick()

    expect(wrapper.text()).toContain('Loading conversation')
  })

  it('handles conversation load error', async () => {
    vi.mocked(conversationsApi.list).mockResolvedValue({
      data: [{ id: 'c1', title: 'Chat', created_at: '2026-08-30T10:00:00Z', updated_at: '2026-08-30T10:00:00Z' }],
      meta: { page: 1, per_page: 25, total: 1, total_pages: 1 },
    })
    vi.mocked(conversationsApi.getById).mockRejectedValue(new Error('Load failed'))
    const wrapper = await mountPage()

    const convBtn = wrapper.findAll('button').find((b) => b.text().includes('Chat'))!
    await convBtn.trigger('click')
    await flushPromises()

    expect(wrapper.text()).toContain('Failed to load conversation')
  })

  // -- New conversation -----------------------------------------------------

  it('new conversation clears active state', async () => {
    vi.mocked(conversationsApi.list).mockResolvedValue({
      data: [{ id: 'c1', title: 'Existing', created_at: '2026-08-30T10:00:00Z', updated_at: '2026-08-30T10:00:00Z' }],
      meta: { page: 1, per_page: 25, total: 1, total_pages: 1 },
    })
    vi.mocked(conversationsApi.getById).mockResolvedValue({
      data: {
        id: 'c1', title: 'Existing', created_at: '2026-08-30T10:00:00Z', updated_at: '2026-08-30T10:00:00Z',
        messages: [{ id: 'm1', role: 'user' as const, content: 'Old msg', position: 0, created_at: '2026-08-30T10:00:00Z' }],
      },
    })
    const wrapper = await mountPage()

    const convBtn = wrapper.findAll('button').find((b) => b.text().includes('Existing'))!
    await convBtn.trigger('click')
    await flushPromises()
    expect(wrapper.text()).toContain('Old msg')

    const newBtn = wrapper.find('[aria-label="New conversation"]')
    await newBtn.trigger('click')
    await flushPromises()

    expect(wrapper.text()).not.toContain('Old msg')
    expect(wrapper.text()).toContain('Ask questions about your customer support data')
  })

  it('new conversation does not make API calls', async () => {
    const wrapper = await mountPage()

    const newBtn = wrapper.find('[aria-label="New conversation"]')
    await newBtn.trigger('click')
    await flushPromises()

    expect(conversationsApi.list).toHaveBeenCalledTimes(1)
    expect(conversationsApi.create).not.toHaveBeenCalled()
  })

  it('newly created conversation appears in history', async () => {
    const wrapper = await mountPage()
    await typeAndSend(wrapper, 'Hello')

    // sampleConversation.title is null → shows "New conversation" in list
    const historyBtns = wrapper.findAll('nav[aria-label="Conversations"] button')
    expect(historyBtns.length).toBeGreaterThanOrEqual(1)
  })

  // -- Routing --------------------------------------------------------------

  it('loads conversation from route param on mount', async () => {
    vi.mocked(conversationsApi.getById).mockResolvedValue({
      data: {
        id: 'route-conv', title: 'Routed', created_at: '2026-08-30T10:00:00Z', updated_at: '2026-08-30T10:00:00Z',
        messages: [{ id: 'm1', role: 'user' as const, content: 'From route', position: 0, created_at: '2026-08-30T10:00:00Z' }],
      },
    })

    const wrapper = await mountPage({ conversationId: 'route-conv' })

    expect(conversationsApi.getById).toHaveBeenCalledWith('route-conv')
    expect(wrapper.text()).toContain('From route')
  })

  it('handles invalid conversation ID from route', async () => {
    vi.mocked(conversationsApi.getById).mockRejectedValue(
      new ApiError({ type: '/errors/not-found', title: 'Not Found', status: 404, detail: 'Conversation not found' }),
    )

    const wrapper = await mountPage({ conversationId: 'bad-id' })

    expect(wrapper.text()).toContain('Conversation not found')
  })

  // -- Sending in existing conversation -------------------------------------

  it('sends message to existing conversation', async () => {
    vi.mocked(conversationsApi.list).mockResolvedValue({
      data: [{ id: 'c1', title: 'Chat', created_at: '2026-08-30T10:00:00Z', updated_at: '2026-08-30T10:00:00Z' }],
      meta: { page: 1, per_page: 25, total: 1, total_pages: 1 },
    })
    vi.mocked(conversationsApi.getById).mockResolvedValue({
      data: {
        id: 'c1', title: 'Chat', created_at: '2026-08-30T10:00:00Z', updated_at: '2026-08-30T10:00:00Z',
        messages: [{ id: 'm1', role: 'user' as const, content: 'Old msg', position: 0, created_at: '2026-08-30T10:00:00Z' }],
      },
    })
    const wrapper = await mountPage()

    const convBtn = wrapper.findAll('button').find((b) => b.text().includes('Chat'))!
    await convBtn.trigger('click')
    await flushPromises()

    await typeAndSend(wrapper, 'Follow-up question')

    expect(conversationsApi.create).not.toHaveBeenCalled()
    expect(conversationsApi.sendMessage).toHaveBeenCalledWith('c1', 'Follow-up question')
  })

  // -- Race condition -------------------------------------------------------

  it('discards stale conversation response', async () => {
    vi.mocked(conversationsApi.list).mockResolvedValue({
      data: [
        { id: 'c1', title: 'First', created_at: '2026-08-30T10:00:00Z', updated_at: '2026-08-30T10:00:00Z' },
        { id: 'c2', title: 'Second', created_at: '2026-08-29T10:00:00Z', updated_at: '2026-08-29T10:00:00Z' },
      ],
      meta: { page: 1, per_page: 25, total: 2, total_pages: 1 },
    })

    let resolveFirst: (v: any) => void
    const firstPromise = new Promise((r) => { resolveFirst = r })
    vi.mocked(conversationsApi.getById)
      .mockImplementationOnce(() => firstPromise as any)
      .mockResolvedValueOnce({
        data: {
          id: 'c2', title: 'Second', created_at: '2026-08-29T10:00:00Z', updated_at: '2026-08-29T10:00:00Z',
          messages: [{ id: 'm2', role: 'user' as const, content: 'Second msg', position: 0, created_at: '2026-08-29T10:00:00Z' }],
        },
      })

    const wrapper = await mountPage()

    const firstBtn = wrapper.findAll('button').find((b) => b.text().includes('First'))!
    await firstBtn.trigger('click')
    await wrapper.vm.$nextTick()

    const secondBtn = wrapper.findAll('button').find((b) => b.text().includes('Second'))!
    await secondBtn.trigger('click')
    await flushPromises()

    expect(wrapper.text()).toContain('Second msg')

    resolveFirst!({
      data: {
        id: 'c1', title: 'First', created_at: '2026-08-30T10:00:00Z', updated_at: '2026-08-30T10:00:00Z',
        messages: [{ id: 'm1', role: 'user' as const, content: 'First msg', position: 0, created_at: '2026-08-30T10:00:00Z' }],
      },
    })
    await flushPromises()

    expect(wrapper.text()).toContain('Second msg')
    expect(wrapper.text()).not.toContain('First msg')
  })

  // -- Accessibility --------------------------------------------------------

  it('history sidebar has accessible label', async () => {
    const wrapper = await mountPage()
    const aside = wrapper.find('aside[aria-label="Conversation history"]')
    expect(aside.exists()).toBe(true)
  })

  it('new conversation button has accessible label', async () => {
    const wrapper = await mountPage()
    const btn = wrapper.find('[aria-label="New conversation"]')
    expect(btn.exists()).toBe(true)
  })

  it('mobile history toggle has accessible label', async () => {
    const wrapper = await mountPage()
    const btn = wrapper.find('[aria-label="Open conversation history"]')
    expect(btn.exists()).toBe(true)
  })
})
