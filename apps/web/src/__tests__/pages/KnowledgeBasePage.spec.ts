import { describe, it, expect, beforeEach, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { createRouter, createWebHistory } from 'vue-router'
import KnowledgeBasePage from '@/pages/KnowledgeBasePage.vue'
import * as documentsApi from '@/api/documents'
import { ApiError } from '@/api/errors'
import type { Document, PaginatedEnvelope } from '@/api/types'

vi.mock('@/api/documents')
vi.mock('@/api/auth', () => ({
  login: vi.fn(),
  register: vi.fn(),
  logout: vi.fn(),
  refresh: vi.fn(),
}))

const sampleDocuments: Document[] = [
  {
    id: 'doc-1',
    title: 'Product FAQ',
    filename: 'product-faq.pdf',
    content_type: 'application/pdf',
    file_size: 1048576,
    status: 'completed',
    error_message: null,
    checksum: 'abc123',
    chunk_count: 12,
    uploaded_by: { id: 'u1', email: 'test@example.com', first_name: 'Test', last_name: 'User' },
    created_at: '2026-08-20T10:00:00Z',
    updated_at: '2026-08-20T10:05:00Z',
  },
  {
    id: 'doc-2',
    title: 'support-guide.txt',
    filename: 'support-guide.txt',
    content_type: 'text/plain',
    file_size: 2048,
    status: 'processing',
    error_message: null,
    checksum: 'def456',
    chunk_count: 0,
    uploaded_by: null,
    created_at: '2026-08-21T14:00:00Z',
    updated_at: '2026-08-21T14:00:00Z',
  },
  {
    id: 'doc-3',
    title: 'broken.csv',
    filename: 'broken.csv',
    content_type: 'text/csv',
    file_size: 512,
    status: 'failed',
    error_message: 'Unable to extract text from document',
    checksum: 'ghi789',
    chunk_count: 0,
    uploaded_by: null,
    created_at: '2026-08-22T09:00:00Z',
    updated_at: '2026-08-22T09:01:00Z',
  },
]

const loadedResponse: PaginatedEnvelope<Document> = {
  data: sampleDocuments,
  meta: { page: 1, per_page: 100, total: 3, total_pages: 1 },
}

const emptyResponse: PaginatedEnvelope<Document> = {
  data: [],
  meta: { page: 1, per_page: 100, total: 0, total_pages: 0 },
}

function setupMock(response: PaginatedEnvelope<Document> | Error = loadedResponse) {
  if (response instanceof Error) {
    vi.mocked(documentsApi.list).mockRejectedValue(response)
  } else {
    vi.mocked(documentsApi.list).mockResolvedValue(response)
  }
  vi.mocked(documentsApi.create).mockResolvedValue({
    data: sampleDocuments[0],
  })
  vi.mocked(documentsApi.destroy).mockResolvedValue(undefined)
  vi.mocked(documentsApi.reprocess).mockResolvedValue({
    data: { ...sampleDocuments[2], status: 'pending', error_message: null },
  })
}

function makeRouter() {
  return createRouter({
    history: createWebHistory(),
    routes: [
      { path: '/app/knowledge-base', name: 'knowledge-base', component: KnowledgeBasePage },
      { path: '/app/dashboard', name: 'dashboard', component: { template: '<div />' } },
    ],
  })
}

async function mountPage(response?: PaginatedEnvelope<Document> | Error) {
  setupMock(response)
  const pinia = createPinia()
  setActivePinia(pinia)
  const router = makeRouter()
  await router.push('/app/knowledge-base')
  await router.isReady()

  const wrapper = mount(KnowledgeBasePage, {
    global: { plugins: [pinia, router] },
  })
  await flushPromises()
  return wrapper
}

function createFile(name: string, content = 'test content', type = 'text/plain'): File {
  return new File([content], name, { type })
}

async function selectFile(wrapper: ReturnType<typeof mount>, file: File) {
  // Show the upload area by clicking "Upload document"
  const uploadDocBtn = wrapper.findAll('button').find((b) => b.text().includes('Upload document'))
  if (uploadDocBtn) {
    await uploadDocBtn.trigger('click')
    await flushPromises()
    await wrapper.vm.$nextTick()
  }

  const input = wrapper.find('input[type="file"]')
  if (!input.exists()) {
    throw new Error('File input not found — upload area may not be visible')
  }
  Object.defineProperty(input.element, 'files', { value: [file], writable: false, configurable: true })
  await input.trigger('change')
  await flushPromises()
}

describe('KnowledgeBasePage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  // -- Page rendering -------------------------------------------------------

  it('shows loading text initially', () => {
    setupMock()
    const pinia = createPinia()
    setActivePinia(pinia)
    const router = makeRouter()
    const wrapper = mount(KnowledgeBasePage, {
      global: { plugins: [pinia, router] },
    })
    expect(wrapper.text()).toContain('Loading documents')
  })

  it('renders page header and description', async () => {
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('Knowledge Base')
    expect(wrapper.text()).toContain('knowledge-backed answers')
  })

  it('renders Upload document button', async () => {
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('Upload document')
  })

  // -- Document list --------------------------------------------------------

  it('renders document titles', async () => {
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('Product FAQ')
    expect(wrapper.text()).toContain('support-guide.txt')
    expect(wrapper.text()).toContain('broken.csv')
  })

  it('shows document count', async () => {
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('3 documents')
  })

  it('shows file type labels', async () => {
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('PDF')
    expect(wrapper.text()).toContain('TXT')
    expect(wrapper.text()).toContain('CSV')
  })

  it('shows file sizes', async () => {
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('1.0 MB')
    expect(wrapper.text()).toContain('2.0 KB')
  })

  it('shows chunk count for completed documents', async () => {
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('12 chunks')
  })

  it('shows dates', async () => {
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('Aug 20, 2026')
  })

  // -- Status badges --------------------------------------------------------

  it('shows Ready badge for completed documents', async () => {
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('Ready')
  })

  it('shows Processing badge for processing documents', async () => {
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('Processing')
  })

  it('shows Failed badge for failed documents', async () => {
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('Failed')
  })

  it('shows error message for failed documents', async () => {
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('Unable to extract text from document')
  })

  // -- Empty state ----------------------------------------------------------

  it('shows empty state when no documents', async () => {
    const wrapper = await mountPage(emptyResponse)
    expect(wrapper.text()).toContain('Your Knowledge Base is empty')
    expect(wrapper.text()).toContain('Upload your first document')
  })

  // -- Error state ----------------------------------------------------------

  it('shows error state on API failure', async () => {
    const wrapper = await mountPage(new Error('Network error'))
    expect(wrapper.text()).toContain('Failed to load documents')
  })

  it('shows retry button on error', async () => {
    const wrapper = await mountPage(new Error('Network error'))
    expect(wrapper.text()).toContain('Try again')
  })

  it('retries on Try again click', async () => {
    const wrapper = await mountPage(new Error('Network error'))
    vi.mocked(documentsApi.list).mockResolvedValue(loadedResponse)

    const retryBtn = wrapper.findAll('button').find((b) => b.text().includes('Try again'))!
    await retryBtn.trigger('click')
    await flushPromises()

    expect(documentsApi.list).toHaveBeenCalledTimes(2)
    expect(wrapper.text()).toContain('Product FAQ')
  })

  // -- Upload ---------------------------------------------------------------

  it('shows upload area when Upload document button clicked', async () => {
    const wrapper = await mountPage()
    const btn = wrapper.findAll('button').find((b) => b.text().includes('Upload document'))!
    await btn.trigger('click')
    await flushPromises()

    expect(wrapper.text()).toContain('Drag and drop your file here')
  })

  it('accepts a valid file', async () => {
    const wrapper = await mountPage()
    const file = createFile('user-manual.pdf', 'pdf content', 'application/pdf')
    await selectFile(wrapper, file)

    expect(wrapper.text()).toContain('user-manual.pdf')
  })

  it('rejects unsupported file extension', async () => {
    const wrapper = await mountPage()
    const file = createFile('image.png', 'binary', 'image/png')
    await selectFile(wrapper, file)

    expect(wrapper.text()).toContain('Please choose a PDF, TXT, Markdown, or CSV file')
  })

  it('rejects empty file', async () => {
    const wrapper = await mountPage()

    // Show upload area
    const uploadBtn = wrapper.findAll('button').find((b) => b.text().includes('Upload document'))!
    await uploadBtn.trigger('click')
    await flushPromises()

    const file = new File([], 'empty.txt', { type: 'text/plain' })
    const input = wrapper.find('input[type="file"]')
    Object.defineProperty(input.element, 'files', { value: [file], writable: false, configurable: true })
    await input.trigger('change')
    await flushPromises()

    expect(wrapper.text()).toContain('The selected file is empty')
  })

  it('calls documentsApi.create on upload', async () => {
    const wrapper = await mountPage()
    const file = createFile('my-upload.txt')
    await selectFile(wrapper, file)

    const uploadBtn = wrapper.findAll('button').find((b) => b.text() === 'Upload')!
    await uploadBtn.trigger('click')
    await flushPromises()

    expect(documentsApi.create).toHaveBeenCalledWith(file)
  })

  it('shows uploading state', async () => {
    const wrapper = await mountPage()
    vi.mocked(documentsApi.create).mockReturnValue(new Promise(() => {}) as any)

    const file = createFile('my-upload.txt')
    await selectFile(wrapper, file)

    const uploadBtn = wrapper.findAll('button').find((b) => b.text().trim() === 'Upload')!
    await uploadBtn.trigger('click')
    await wrapper.vm.$nextTick()

    expect(wrapper.text()).toContain('Uploading')
  })

  it('refreshes document list after successful upload', async () => {
    const wrapper = await mountPage()
    const file = createFile('my-upload.txt')
    await selectFile(wrapper, file)

    const uploadBtn = wrapper.findAll('button').find((b) => b.text() === 'Upload')!
    await uploadBtn.trigger('click')
    await flushPromises()

    // list() called once on mount + once after upload
    expect(documentsApi.list).toHaveBeenCalledTimes(2)
  })

  it('shows upload error from API', async () => {
    const wrapper = await mountPage()
    vi.mocked(documentsApi.create).mockRejectedValue(
      new ApiError({
        type: '/errors/validation',
        title: 'Validation Error',
        status: 422,
        detail: 'Duplicate document',
        errors: { checksum: ['a document with this content already exists in this organization'] },
      }),
    )
    const file = createFile('my-upload.txt')
    await selectFile(wrapper, file)

    const uploadBtn = wrapper.findAll('button').find((b) => b.text() === 'Upload')!
    await uploadBtn.trigger('click')
    await flushPromises()

    expect(wrapper.text()).toContain('a document with this content already exists')
  })

  it('shows generic upload error for non-API errors', async () => {
    const wrapper = await mountPage()
    vi.mocked(documentsApi.create).mockRejectedValue(new Error('Network failure'))
    const file = createFile('my-upload.txt')
    await selectFile(wrapper, file)

    // Verify upload area is visible (button shows "Cancel")
    expect(wrapper.text()).toContain('Cancel')

    const uploadBtn = wrapper.findAll('button').find((b) => b.text() === 'Upload')!
    await uploadBtn.trigger('click')
    await flushPromises()

    // After error, upload area should still be visible with error message
    const alertEl = wrapper.find('[role="alert"]')
    expect(alertEl.exists()).toBe(true)
    expect(alertEl.text()).toContain('Upload failed')
  })

  it('allows removing a selected file', async () => {
    const wrapper = await mountPage()
    const file = createFile('my-unique-upload.txt')
    await selectFile(wrapper, file)

    expect(wrapper.text()).toContain('my-unique-upload.txt')

    const removeBtn = wrapper.find('button[aria-label="Remove selected file"]')
    await removeBtn.trigger('click')
    await flushPromises()

    expect(wrapper.text()).not.toContain('my-unique-upload.txt')
  })

  // -- Delete ---------------------------------------------------------------

  it('shows confirm/cancel on first delete click', async () => {
    const wrapper = await mountPage()
    const deleteBtn = wrapper.findAll('button').find((b) => b.text() === 'Delete')!
    await deleteBtn.trigger('click')
    await flushPromises()

    expect(wrapper.text()).toContain('Confirm')
    expect(wrapper.text()).toContain('Cancel')
  })

  it('cancels delete on Cancel click', async () => {
    const wrapper = await mountPage()
    const deleteBtn = wrapper.findAll('button').find((b) => b.text() === 'Delete')!
    await deleteBtn.trigger('click')
    await flushPromises()

    const cancelBtn = wrapper.findAll('button').find((b) => b.text() === 'Cancel')!
    await cancelBtn.trigger('click')
    await flushPromises()

    expect(documentsApi.destroy).not.toHaveBeenCalled()
  })

  it('deletes document on Confirm click', async () => {
    const wrapper = await mountPage()

    // Find a Delete button for the first (completed) document
    const deleteBtn = wrapper.findAll('button').find((b) => b.text() === 'Delete')!
    await deleteBtn.trigger('click')
    await flushPromises()

    const confirmBtn = wrapper.findAll('button').find((b) => b.text() === 'Confirm')!
    await confirmBtn.trigger('click')
    await flushPromises()

    expect(documentsApi.destroy).toHaveBeenCalled()
  })

  it('removes document from list after delete', async () => {
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('Product FAQ')

    // Click Delete, then Confirm for first document
    const deleteBtn = wrapper.findAll('button').find((b) => b.text() === 'Delete')!
    await deleteBtn.trigger('click')
    await flushPromises()

    const confirmBtn = wrapper.findAll('button').find((b) => b.text() === 'Confirm')!
    await confirmBtn.trigger('click')
    await flushPromises()

    expect(wrapper.text()).not.toContain('Product FAQ')
  })

  // -- Reprocess ------------------------------------------------------------

  it('shows Reprocess button for failed documents', async () => {
    const wrapper = await mountPage()
    const buttons = wrapper.findAll('button').filter((b) => b.text().includes('Reprocess'))
    expect(buttons.length).toBeGreaterThan(0)
  })

  it('calls reprocess API on click', async () => {
    const wrapper = await mountPage()
    const reprocessBtn = wrapper.findAll('button').find((b) => b.text().includes('Reprocess'))!
    await reprocessBtn.trigger('click')
    await flushPromises()

    expect(documentsApi.reprocess).toHaveBeenCalled()
  })

  // -- Navigation -----------------------------------------------------------

  it('calls documentsApi.list on mount', async () => {
    await mountPage()
    expect(documentsApi.list).toHaveBeenCalledTimes(1)
  })
})
