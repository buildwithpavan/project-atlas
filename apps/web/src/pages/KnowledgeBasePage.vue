<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed } from 'vue'
import * as documentsApi from '@/api/documents'
import { ApiError } from '@/api/errors'
import type { Document, DocumentStatus, PaginatedEnvelope } from '@/api/types'
import { ABadge, AButton } from '@/components/ui'

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

const documents = ref<Document[]>([])
const loading = ref(true)
const error = ref<string | null>(null)
const totalDocuments = ref(0)

// Upload state
const selectedFile = ref<File | null>(null)
const uploading = ref(false)
const uploadError = ref<string | null>(null)
const validationError = ref<string | null>(null)
const dragActive = ref(false)
const fileInput = ref<HTMLInputElement | null>(null)
const showUploadArea = ref(false)

// Delete state
const deletingId = ref<string | null>(null)
const confirmDeleteId = ref<string | null>(null)

// Reprocess state
const reprocessingId = ref<string | null>(null)

// Polling
let pollTimer: ReturnType<typeof setInterval> | null = null

const ACCEPTED_EXTENSIONS = ['.pdf', '.txt', '.md', '.csv']
const MAX_FILE_SIZE = 50 * 1024 * 1024 // 50 MB

const hasProcessingDocuments = computed(() =>
  documents.value.some((d) => d.status === 'pending' || d.status === 'processing'),
)

const isEmpty = computed(() => !loading.value && !error.value && documents.value.length === 0)

// ---------------------------------------------------------------------------
// Document list
// ---------------------------------------------------------------------------

async function fetchDocuments() {
  // Don't reset loading if we already have data (poll refresh)
  if (documents.value.length === 0) loading.value = true
  error.value = null

  try {
    const res: PaginatedEnvelope<Document> = await documentsApi.list({ per_page: 100 })
    documents.value = res.data
    totalDocuments.value = res.meta.total
  } catch {
    if (documents.value.length === 0) {
      error.value = 'Failed to load documents'
    }
  } finally {
    loading.value = false
  }
}

// ---------------------------------------------------------------------------
// Polling for processing documents
// ---------------------------------------------------------------------------

function startPolling() {
  stopPolling()
  pollTimer = setInterval(() => {
    if (hasProcessingDocuments.value) {
      fetchDocuments()
    } else {
      stopPolling()
    }
  }, 5000)
}

function stopPolling() {
  if (pollTimer) {
    clearInterval(pollTimer)
    pollTimer = null
  }
}

// ---------------------------------------------------------------------------
// File validation & upload
// ---------------------------------------------------------------------------

function validateFile(file: File): string | null {
  const name = file.name.toLowerCase()
  const hasValidExtension = ACCEPTED_EXTENSIONS.some((ext) => name.endsWith(ext))

  if (!hasValidExtension) {
    return 'Please choose a PDF, TXT, Markdown, or CSV file.'
  }
  if (file.size === 0) {
    return 'The selected file is empty.'
  }
  if (file.size > MAX_FILE_SIZE) {
    return 'File must be less than 50 MB.'
  }
  return null
}

function onFileSelect(file: File) {
  validationError.value = null
  uploadError.value = null

  const err = validateFile(file)
  if (err) {
    validationError.value = err
    selectedFile.value = null
    return
  }

  selectedFile.value = file
}

function openPicker() {
  fileInput.value?.click()
}

function onFileChange(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (file) onFileSelect(file)
  input.value = ''
}

function onDragEnter(e: DragEvent) {
  e.preventDefault()
  dragActive.value = true
}

function onDragOver(e: DragEvent) {
  e.preventDefault()
  dragActive.value = true
}

function onDragLeave(e: DragEvent) {
  e.preventDefault()
  const related = e.relatedTarget as Node | null
  const target = e.currentTarget as HTMLElement
  if (!related || !target.contains(related)) {
    dragActive.value = false
  }
}

function onDrop(e: DragEvent) {
  e.preventDefault()
  dragActive.value = false
  const file = e.dataTransfer?.files[0]
  if (file) onFileSelect(file)
}

function removeFile() {
  selectedFile.value = null
  validationError.value = null
  uploadError.value = null
}

async function handleUpload() {
  if (!selectedFile.value || uploading.value) return

  uploading.value = true
  uploadError.value = null

  try {
    await documentsApi.create(selectedFile.value)
    selectedFile.value = null
    showUploadArea.value = false
    await fetchDocuments()
    if (hasProcessingDocuments.value) startPolling()
  } catch (err: unknown) {
    if (err instanceof ApiError) {
      if (err.isValidation && err.errors) {
        const messages = Object.values(err.errors).flat()
        uploadError.value = messages.join(' ')
      } else {
        uploadError.value = err.detail
      }
    } else {
      uploadError.value = 'Upload failed. Please try again.'
    }
  } finally {
    uploading.value = false
  }
}

function toggleUploadArea() {
  showUploadArea.value = !showUploadArea.value
  if (!showUploadArea.value) {
    selectedFile.value = null
    validationError.value = null
    uploadError.value = null
  }
}

// ---------------------------------------------------------------------------
// Document actions
// ---------------------------------------------------------------------------

async function handleDelete(id: string) {
  if (confirmDeleteId.value !== id) {
    confirmDeleteId.value = id
    return
  }

  deletingId.value = id
  confirmDeleteId.value = null

  try {
    await documentsApi.destroy(id)
    documents.value = documents.value.filter((d) => d.id !== id)
    totalDocuments.value = Math.max(0, totalDocuments.value - 1)
  } catch (err: unknown) {
    error.value = err instanceof ApiError ? err.detail : 'Failed to delete document'
  } finally {
    deletingId.value = null
  }
}

function cancelDelete() {
  confirmDeleteId.value = null
}

async function handleReprocess(doc: Document) {
  if (doc.status === 'processing') return

  reprocessingId.value = doc.id

  try {
    const res = await documentsApi.reprocess(doc.id)
    const idx = documents.value.findIndex((d) => d.id === doc.id)
    if (idx !== -1) documents.value[idx] = res.data
    if (hasProcessingDocuments.value) startPolling()
  } catch (err: unknown) {
    error.value = err instanceof ApiError ? err.detail : 'Failed to reprocess document'
  } finally {
    reprocessingId.value = null
  }
}

// ---------------------------------------------------------------------------
// Formatting helpers
// ---------------------------------------------------------------------------

const statusConfig: Record<DocumentStatus, { label: string; variant: 'default' | 'success' | 'warning' | 'error' | 'info' }> = {
  pending: { label: 'Pending', variant: 'default' },
  processing: { label: 'Processing', variant: 'info' },
  completed: { label: 'Ready', variant: 'success' },
  failed: { label: 'Failed', variant: 'error' },
}

function formatFileSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
}

function formatDate(dateStr: string): string {
  return new Date(dateStr).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  })
}

function formatContentType(contentType: string): string {
  const map: Record<string, string> = {
    'application/pdf': 'PDF',
    'text/plain': 'TXT',
    'text/markdown': 'Markdown',
    'text/x-markdown': 'Markdown',
    'text/csv': 'CSV',
  }
  return map[contentType] ?? contentType
}

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

onMounted(async () => {
  await fetchDocuments()
  if (hasProcessingDocuments.value) startPolling()
})

onUnmounted(() => {
  stopPolling()
})
</script>

<template>
  <div class="space-y-6">
    <!-- Header -->
    <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <h1 class="text-2xl font-bold text-voceive-text-primary">Knowledge Base</h1>
        <p class="mt-1 text-sm text-voceive-text-secondary">
          Manage the documents Voceive uses to provide knowledge-backed answers.
        </p>
      </div>
      <AButton
        variant="primary"
        size="md"
        @click="toggleUploadArea"
      >
        {{ showUploadArea ? 'Cancel' : 'Upload document' }}
      </AButton>
    </div>

    <!-- Upload area -->
    <div
      v-if="showUploadArea || isEmpty"
      class="rounded-voceive-md border border-voceive-border bg-voceive-surface p-6"
    >
      <!-- Dropzone -->
      <div
        v-if="!selectedFile"
        class="relative rounded-voceive-md border-2 border-dashed transition-colors cursor-pointer"
        :class="[
          dragActive
            ? 'border-voceive-brand bg-voceive-brand-subtle'
            : 'border-voceive-border hover:border-voceive-text-muted',
          uploading ? 'opacity-60 pointer-events-none' : '',
        ]"
        role="button"
        tabindex="0"
        :aria-label="dragActive ? 'Drop your file here' : 'Upload area. Click or drag a file to upload'"
        @click="openPicker"
        @keydown.enter="openPicker"
        @keydown.space.prevent="openPicker"
        @dragenter="onDragEnter"
        @dragover="onDragOver"
        @dragleave="onDragLeave"
        @drop="onDrop"
      >
        <div class="flex flex-col items-center justify-center px-6 py-12 text-center">
          <div class="size-12 rounded-full bg-voceive-brand-subtle flex items-center justify-center mb-4">
            <svg
              class="size-6 text-voceive-brand"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5"
              />
            </svg>
          </div>
          <p class="text-sm font-medium text-voceive-text-primary">
            <span v-if="dragActive">Drop your file here</span>
            <span v-else>Drag and drop your file here</span>
          </p>
          <p class="mt-1 text-xs text-voceive-text-muted">or</p>
          <button
            type="button"
            class="voceive-focus-ring mt-2 inline-flex items-center rounded-voceive px-4 py-2 text-sm font-medium text-voceive-brand hover:bg-voceive-brand-subtle transition-colors"
            @click.stop="openPicker"
          >
            Choose file
          </button>
          <p class="mt-3 text-xs text-voceive-text-muted">
            PDF, TXT, Markdown, or CSV — up to 50 MB
          </p>
        </div>

        <input
          ref="fileInput"
          type="file"
          accept=".pdf,.txt,.md,.csv,application/pdf,text/plain,text/markdown,text/csv"
          class="sr-only"
          aria-label="Choose file to upload"
          @change="onFileChange"
        >
      </div>

      <!-- Selected file info -->
      <div v-else class="flex items-center gap-3 rounded-voceive border border-voceive-border bg-voceive-surface px-4 py-3">
        <div class="flex-shrink-0 size-10 rounded-voceive bg-voceive-brand-subtle flex items-center justify-center">
          <svg
            class="size-5 text-voceive-brand"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="1.5"
            aria-hidden="true"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z"
            />
          </svg>
        </div>
        <div class="min-w-0 flex-1">
          <p class="truncate text-sm font-medium text-voceive-text-primary">{{ selectedFile.name }}</p>
          <p class="text-xs text-voceive-text-muted">{{ formatFileSize(selectedFile.size) }}</p>
        </div>
        <button
          type="button"
          class="voceive-focus-ring flex-shrink-0 rounded-voceive p-1.5 text-voceive-text-muted hover:bg-voceive-surface-muted hover:text-voceive-text-primary transition-colors"
          aria-label="Remove selected file"
          @click="removeFile"
        >
          <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>

      <!-- Validation error -->
      <p
        v-if="validationError"
        role="alert"
        class="mt-3 text-sm text-voceive-error"
      >
        {{ validationError }}
      </p>

      <!-- Upload error -->
      <p
        v-if="uploadError"
        role="alert"
        class="mt-3 text-sm text-voceive-error"
      >
        {{ uploadError }}
      </p>

      <!-- Upload button -->
      <div v-if="selectedFile" class="mt-4">
        <AButton
          variant="primary"
          size="md"
          :loading="uploading"
          :disabled="uploading"
          @click="handleUpload"
        >
          {{ uploading ? 'Uploading…' : 'Upload' }}
        </AButton>
      </div>
    </div>

    <!-- Loading state -->
    <div v-if="loading" class="flex items-center justify-center py-12">
      <div class="text-sm text-voceive-text-muted">Loading documents…</div>
    </div>

    <!-- Error state -->
    <div
      v-else-if="error && documents.length === 0"
      class="rounded-voceive-md bg-voceive-error-subtle border border-voceive-error/20 p-4"
    >
      <p class="text-sm text-voceive-error">{{ error }}</p>
      <button
        class="mt-2 text-sm font-medium text-voceive-error underline hover:no-underline"
        @click="fetchDocuments"
      >
        Try again
      </button>
    </div>

    <!-- Empty state -->
    <div
      v-else-if="isEmpty && !showUploadArea"
      class="rounded-voceive-lg bg-voceive-surface border border-voceive-border p-12 text-center"
    >
      <div class="mx-auto max-w-sm">
        <div class="mx-auto mb-4 size-12 rounded-full bg-voceive-brand-subtle flex items-center justify-center">
          <svg
            class="size-6 text-voceive-brand"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="1.5"
            aria-hidden="true"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M12 6.042A8.967 8.967 0 006 3.75c-1.052 0-2.062.18-3 .512v14.25A8.987 8.987 0 016 18c2.305 0 4.408.867 6 2.292m0-14.25a8.966 8.966 0 016-2.292c1.052 0 2.062.18 3 .512v14.25A8.987 8.987 0 0018 18a8.967 8.967 0 00-6 2.292m0-14.25v14.25"
            />
          </svg>
        </div>
        <h3 class="text-lg font-semibold text-voceive-text-primary">Your Knowledge Base is empty</h3>
        <p class="mt-2 text-sm text-voceive-text-secondary">
          Upload documents to build the knowledge that powers Ask Voceive. Documents are processed, chunked, and embedded so Voceive can provide evidence-backed answers.
        </p>
        <div class="mt-6">
          <AButton variant="primary" size="md" @click="showUploadArea = true">
            Upload your first document
          </AButton>
        </div>
      </div>
    </div>

    <!-- Inline error banner (shown when we have documents but an action failed) -->
    <div
      v-if="error && documents.length > 0"
      class="rounded-voceive-md bg-voceive-error-subtle border border-voceive-error/20 p-3 flex items-center justify-between"
    >
      <p class="text-sm text-voceive-error">{{ error }}</p>
      <button
        class="text-sm font-medium text-voceive-error underline hover:no-underline"
        @click="error = null"
      >
        Dismiss
      </button>
    </div>

    <!-- Document list -->
    <div v-if="!loading && documents.length > 0" class="space-y-3">
      <p class="text-sm text-voceive-text-muted">
        {{ totalDocuments }} document{{ totalDocuments === 1 ? '' : 's' }}
      </p>

      <div
        v-for="doc in documents"
        :key="doc.id"
        class="rounded-voceive-lg bg-voceive-surface border border-voceive-border p-4 sm:p-5"
      >
        <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between sm:gap-4">
          <!-- Left: document info -->
          <div class="min-w-0 flex-1">
            <div class="flex flex-wrap items-center gap-2 mb-1">
              <h3 class="text-sm font-semibold text-voceive-text-primary truncate">{{ doc.title }}</h3>
              <ABadge :variant="statusConfig[doc.status].variant">
                <!-- Processing spinner -->
                <svg
                  v-if="doc.status === 'processing'"
                  class="animate-spin -ml-0.5 mr-1 size-3"
                  viewBox="0 0 24 24"
                  fill="none"
                  aria-hidden="true"
                >
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                </svg>
                {{ statusConfig[doc.status].label }}
              </ABadge>
            </div>

            <div class="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-voceive-text-muted">
              <span>{{ formatContentType(doc.content_type) }}</span>
              <span>{{ formatFileSize(doc.file_size) }}</span>
              <span v-if="doc.status === 'completed' && doc.chunk_count > 0">
                {{ doc.chunk_count }} chunk{{ doc.chunk_count === 1 ? '' : 's' }}
              </span>
              <span>{{ formatDate(doc.created_at) }}</span>
            </div>

            <!-- Error message for failed documents -->
            <p
              v-if="doc.status === 'failed' && doc.error_message"
              class="mt-2 text-xs text-voceive-error"
            >
              {{ doc.error_message }}
            </p>
          </div>

          <!-- Right: actions -->
          <div class="flex items-center gap-2 shrink-0">
            <!-- Reprocess (for failed or completed docs) -->
            <AButton
              v-if="doc.status === 'failed' || doc.status === 'completed'"
              variant="ghost"
              size="sm"
              :loading="reprocessingId === doc.id"
              :disabled="reprocessingId === doc.id"
              @click="handleReprocess(doc)"
            >
              Reprocess
            </AButton>

            <!-- Delete -->
            <template v-if="confirmDeleteId === doc.id">
              <AButton
                variant="danger"
                size="sm"
                :loading="deletingId === doc.id"
                @click="handleDelete(doc.id)"
              >
                Confirm
              </AButton>
              <AButton
                variant="ghost"
                size="sm"
                @click="cancelDelete"
              >
                Cancel
              </AButton>
            </template>
            <AButton
              v-else
              variant="ghost"
              size="sm"
              :disabled="deletingId === doc.id || doc.status === 'processing'"
              @click="handleDelete(doc.id)"
            >
              Delete
            </AButton>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
