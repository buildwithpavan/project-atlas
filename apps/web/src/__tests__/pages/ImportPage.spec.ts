import { describe, it, expect, beforeEach, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { createRouter, createWebHistory } from 'vue-router'
import ImportPage from '@/pages/ImportPage.vue'
import * as uploadsApi from '@/api/uploads'
import { ApiError } from '@/api/errors'
import type { DataEnvelope, Upload } from '@/api/types'

vi.mock('@/api/uploads')
vi.mock('@/api/auth', () => ({
  login: vi.fn(),
  register: vi.fn(),
  logout: vi.fn(),
  refresh: vi.fn(),
}))

const baseUpload: Upload = {
  id: 'upload-1',
  filename: 'tickets.csv',
  status: 'pending',
  total_records: null,
  processed_records: 0,
  failed_records: 0,
  created_at: '2026-08-11T12:00:00Z',
  updated_at: '2026-08-11T12:00:00Z',
}

function makeRouter() {
  return createRouter({
    history: createWebHistory(),
    routes: [
      { path: '/app/import', name: 'import', component: ImportPage },
      { path: '/app/dashboard', name: 'dashboard', component: { template: '<div />' } },
      { path: '/app/tickets', name: 'tickets', component: { template: '<div />' } },
    ],
  })
}

async function mountPage() {
  const pinia = createPinia()
  setActivePinia(pinia)
  const router = makeRouter()
  await router.push('/app/import')
  await router.isReady()

  const wrapper = mount(ImportPage, {
    global: { plugins: [pinia, router] },
  })
  await flushPromises()
  return wrapper
}

function createFile(name: string, content = 'subject\ntest', type = 'text/csv'): File {
  return new File([content], name, { type })
}

async function selectFile(wrapper: ReturnType<typeof mount>, file: File) {
  const input = wrapper.find('input[type="file"]')
  Object.defineProperty(input.element, 'files', { value: [file], writable: false, configurable: true })
  await input.trigger('change')
  await flushPromises()
}

describe('ImportPage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  // -- Initial state --------------------------------------------------------

  it('renders header and description', async () => {
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('Import customer data')
    expect(wrapper.text()).toContain('Upload a CSV file')
  })

  it('renders upload dropzone', async () => {
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('Drag and drop your CSV file here')
    expect(wrapper.text()).toContain('Choose CSV file')
  })

  it('renders format guide', async () => {
    const wrapper = await mountPage()
    expect(wrapper.text()).toContain('Expected CSV columns')
    expect(wrapper.text()).toContain('subject')
    expect(wrapper.text()).toContain('description')
    expect(wrapper.text()).toContain('customer_name')
  })

  it('upload button is disabled with no file', async () => {
    const wrapper = await mountPage()
    const btn = wrapper.findAll('button').find(b => b.text().includes('Upload and analyze'))
    expect(btn).toBeTruthy()
    expect(btn!.attributes('disabled')).toBeDefined()
  })

  // -- File selection -------------------------------------------------------

  it('accepts a CSV file', async () => {
    const wrapper = await mountPage()
    const file = createFile('data.csv')
    await selectFile(wrapper, file)

    expect(wrapper.text()).toContain('data.csv')
    const btn = wrapper.findAll('button').find(b => b.text().includes('Upload and analyze'))
    expect(btn!.attributes('disabled')).toBeUndefined()
  })

  it('shows file size for selected file', async () => {
    const wrapper = await mountPage()
    const file = createFile('data.csv')
    await selectFile(wrapper, file)
    // File has some bytes
    expect(wrapper.text()).toMatch(/\d+\s*B/)
  })

  it('rejects non-CSV file', async () => {
    const wrapper = await mountPage()
    const file = createFile('data.xlsx', 'binary', 'application/vnd.ms-excel')
    await selectFile(wrapper, file)

    expect(wrapper.text()).toContain('Please choose a CSV file')
    expect(wrapper.text()).not.toContain('data.xlsx')
  })

  it('rejects empty CSV file', async () => {
    const wrapper = await mountPage()
    const file = new File([], 'empty.csv', { type: 'text/csv' })
    await selectFile(wrapper, file)

    expect(wrapper.text()).toContain('The selected file is empty')
  })

  it('allows removing selected file', async () => {
    const wrapper = await mountPage()
    const file = createFile('data.csv')
    await selectFile(wrapper, file)
    expect(wrapper.text()).toContain('data.csv')

    const removeBtn = wrapper.find('button[aria-label="Remove selected file"]')
    await removeBtn.trigger('click')
    await flushPromises()

    expect(wrapper.text()).not.toContain('data.csv')
    expect(wrapper.text()).toContain('Drag and drop your CSV file here')
  })

  it('resets validation error when selecting a new file', async () => {
    const wrapper = await mountPage()

    // Select invalid file
    const bad = createFile('data.xlsx')
    await selectFile(wrapper, bad)
    expect(wrapper.text()).toContain('Please choose a CSV file')

    // Select valid file
    const good = createFile('data.csv')
    await selectFile(wrapper, good)
    expect(wrapper.text()).not.toContain('Please choose a CSV file')
    expect(wrapper.text()).toContain('data.csv')
  })

  // -- Upload ---------------------------------------------------------------

  it('calls uploadsApi.create on upload', async () => {
    vi.mocked(uploadsApi.create).mockResolvedValue({ data: baseUpload })

    const wrapper = await mountPage()
    const file = createFile('data.csv')
    await selectFile(wrapper, file)

    const btn = wrapper.findAll('button').find(b => b.text().includes('Upload and analyze'))!
    await btn.trigger('click')
    await flushPromises()

    expect(uploadsApi.create).toHaveBeenCalledTimes(1)
    expect(uploadsApi.create).toHaveBeenCalledWith(file)
  })

  it('shows loading state during upload', async () => {
    let resolveUpload!: (v: DataEnvelope<Upload>) => void
    vi.mocked(uploadsApi.create).mockReturnValue(
      new Promise((resolve) => { resolveUpload = resolve }),
    )

    const wrapper = await mountPage()
    const file = createFile('data.csv')
    await selectFile(wrapper, file)

    const btn = wrapper.findAll('button').find(b => b.text().includes('Upload and analyze'))!
    await btn.trigger('click')
    await flushPromises()

    expect(wrapper.text()).toContain('Uploading…')

    resolveUpload({ data: baseUpload })
    await flushPromises()
  })

  it('shows success state after upload', async () => {
    vi.mocked(uploadsApi.create).mockResolvedValue({ data: baseUpload })

    const wrapper = await mountPage()
    const file = createFile('data.csv')
    await selectFile(wrapper, file)

    const btn = wrapper.findAll('button').find(b => b.text().includes('Upload and analyze'))!
    await btn.trigger('click')
    await flushPromises()

    expect(wrapper.text()).toContain('Import started')
    expect(wrapper.text()).toContain('tickets.csv')
    expect(wrapper.text()).toContain('View Dashboard')
    expect(wrapper.text()).toContain('View Tickets')
  })

  it('success state has navigation links', async () => {
    vi.mocked(uploadsApi.create).mockResolvedValue({ data: baseUpload })

    const wrapper = await mountPage()
    const file = createFile('data.csv')
    await selectFile(wrapper, file)

    const btn = wrapper.findAll('button').find(b => b.text().includes('Upload and analyze'))!
    await btn.trigger('click')
    await flushPromises()

    expect(wrapper.find('a[href="/app/dashboard"]').exists()).toBe(true)
    expect(wrapper.find('a[href="/app/tickets"]').exists()).toBe(true)
  })

  // -- Error handling -------------------------------------------------------

  it('shows error state on API error', async () => {
    vi.mocked(uploadsApi.create).mockRejectedValue(
      new ApiError({
        type: '/errors/validation',
        title: 'Validation Error',
        status: 422,
        detail: 'CSV is missing required column: subject',
      }),
    )

    const wrapper = await mountPage()
    const file = createFile('data.csv')
    await selectFile(wrapper, file)

    const btn = wrapper.findAll('button').find(b => b.text().includes('Upload and analyze'))!
    await btn.trigger('click')
    await flushPromises()

    expect(wrapper.text()).toContain('Upload failed')
    expect(wrapper.text()).toContain('CSV is missing required column: subject')
  })

  it('shows validation errors from API', async () => {
    vi.mocked(uploadsApi.create).mockRejectedValue(
      new ApiError({
        type: '/errors/validation',
        title: 'Validation Error',
        status: 422,
        detail: 'Validation failed',
        errors: { file: ['is not a valid CSV format'] },
      }),
    )

    const wrapper = await mountPage()
    const file = createFile('data.csv')
    await selectFile(wrapper, file)

    const btn = wrapper.findAll('button').find(b => b.text().includes('Upload and analyze'))!
    await btn.trigger('click')
    await flushPromises()

    expect(wrapper.text()).toContain('is not a valid CSV format')
  })

  it('shows generic message on non-API error', async () => {
    vi.mocked(uploadsApi.create).mockRejectedValue(new Error('Network failure'))

    const wrapper = await mountPage()
    const file = createFile('data.csv')
    await selectFile(wrapper, file)

    const btn = wrapper.findAll('button').find(b => b.text().includes('Upload and analyze'))!
    await btn.trigger('click')
    await flushPromises()

    expect(wrapper.text()).toContain("Voceive couldn't process this file")
  })

  it('error has retry button that resets state', async () => {
    vi.mocked(uploadsApi.create).mockRejectedValue(new Error('fail'))

    const wrapper = await mountPage()
    const file = createFile('data.csv')
    await selectFile(wrapper, file)

    const btn = wrapper.findAll('button').find(b => b.text().includes('Upload and analyze'))!
    await btn.trigger('click')
    await flushPromises()

    expect(wrapper.text()).toContain('Upload failed')

    const retryBtn = wrapper.findAll('button').find(b => b.text().includes('Try again'))!
    await retryBtn.trigger('click')
    await flushPromises()

    // Should be back to idle state
    expect(wrapper.text()).toContain('Drag and drop your CSV file here')
    expect(wrapper.text()).not.toContain('Upload failed')
  })

  // -- Duplicate upload prevention ------------------------------------------

  it('disables upload button while uploading', async () => {
    let resolveUpload!: (v: DataEnvelope<Upload>) => void
    vi.mocked(uploadsApi.create).mockReturnValue(
      new Promise((resolve) => { resolveUpload = resolve }),
    )

    const wrapper = await mountPage()
    const file = createFile('data.csv')
    await selectFile(wrapper, file)

    const btn = wrapper.findAll('button').find(b => b.text().includes('Upload and analyze'))!
    await btn.trigger('click')
    await flushPromises()

    // Button should now show uploading and be disabled
    const uploadingBtn = wrapper.findAll('button').find(b => b.text().includes('Uploading'))
    expect(uploadingBtn?.attributes('disabled')).toBeDefined()

    resolveUpload({ data: baseUpload })
    await flushPromises()
  })
})
