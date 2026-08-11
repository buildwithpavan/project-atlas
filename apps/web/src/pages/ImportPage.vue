<script setup lang="ts">
/* eslint-disable no-undef */
import { ref, computed } from 'vue'
import * as uploadsApi from '@/api/uploads'
import { ApiError } from '@/api/errors'
import type { Upload } from '@/api/types'

import ImportDropzone from '@/components/import/ImportDropzone.vue'
import ImportFileInfo from '@/components/import/ImportFileInfo.vue'
import ImportFormatGuide from '@/components/import/ImportFormatGuide.vue'
import ImportProcessing from '@/components/import/ImportProcessing.vue'
import ImportSuccess from '@/components/import/ImportSuccess.vue'
import ImportError from '@/components/import/ImportError.vue'

type PageState = 'idle' | 'uploading' | 'processing' | 'success' | 'error'

const state = ref<PageState>('idle')
const selectedFile = ref<File | null>(null)
const validationError = ref<string | null>(null)
const uploadError = ref<string | null>(null)
const uploadResult = ref<Upload | null>(null)

const canUpload = computed(() =>
  selectedFile.value !== null && validationError.value === null && state.value === 'idle',
)

function validateFile(file: File): string | null {
  const name = file.name.toLowerCase()
  if (!name.endsWith('.csv')) {
    return 'Please choose a CSV file.'
  }
  if (file.size === 0) {
    return 'The selected file is empty. Please choose a CSV file with data.'
  }
  return null
}

function onFileSelect(file: File) {
  // Reset previous state
  validationError.value = null
  uploadError.value = null

  const error = validateFile(file)
  if (error) {
    validationError.value = error
    selectedFile.value = null
    return
  }

  selectedFile.value = file
}

function removeFile() {
  selectedFile.value = null
  validationError.value = null
  uploadError.value = null
}

async function handleUpload() {
  if (!selectedFile.value || state.value !== 'idle') return

  state.value = 'uploading'
  uploadError.value = null

  try {
    const response = await uploadsApi.create(selectedFile.value)
    uploadResult.value = response.data

    // Determine state based on upload status
    if (response.data.status === 'completed') {
      state.value = 'success'
    } else if (response.data.status === 'failed') {
      state.value = 'error'
      uploadError.value = 'The upload could not be processed. Please check the CSV format and try again.'
    } else {
      // pending or processing
      state.value = 'success'
    }
  } catch (err: unknown) {
    state.value = 'error'
    if (err instanceof ApiError) {
      if (err.isValidation && err.errors) {
        const messages = Object.values(err.errors).flat()
        uploadError.value = messages.join(' ')
      } else {
        uploadError.value = err.detail
      }
    } else {
      uploadError.value = "Atlas couldn't process this file. Please check the CSV format and try again."
    }
  }
}

function handleRetry() {
  state.value = 'idle'
  selectedFile.value = null
  uploadError.value = null
  uploadResult.value = null
}
</script>

<template>
  <div class="mx-auto max-w-2xl">
    <!-- Header -->
    <div class="mb-8">
      <h1 class="text-2xl font-bold text-atlas-text-primary">
        Import customer data
      </h1>
      <p class="mt-2 text-sm text-atlas-text-muted">
        Upload a CSV file with customer conversations. Atlas will analyze the data for sentiment, categories, and actionable insights across your dashboard, tickets, and reports.
      </p>
    </div>

    <!-- Processing state -->
    <div
      v-if="state === 'processing' && uploadResult"
      class="rounded-atlas-md border border-atlas-border bg-atlas-surface p-6"
    >
      <ImportProcessing :upload="uploadResult" />
    </div>

    <!-- Success state -->
    <div
      v-else-if="state === 'success' && uploadResult"
      class="rounded-atlas-md border border-atlas-border bg-atlas-surface p-6"
    >
      <ImportSuccess :upload="uploadResult" />
    </div>

    <!-- Error state -->
    <div
      v-else-if="state === 'error'"
      class="rounded-atlas-md border border-atlas-border bg-atlas-surface p-6"
    >
      <ImportError
        :message="uploadError ?? undefined"
        @retry="handleRetry"
      />
    </div>

    <!-- Upload form -->
    <template v-else>
      <div class="space-y-5">
        <!-- Main upload card -->
        <div class="rounded-atlas-md border border-atlas-border bg-atlas-surface p-6">
          <!-- Dropzone / file info -->
          <ImportDropzone
            v-if="!selectedFile"
            :disabled="state === 'uploading'"
            @select="onFileSelect"
          />

          <ImportFileInfo
            v-else
            :filename="selectedFile.name"
            :size="selectedFile.size"
            @remove="removeFile"
          />

          <!-- Validation error -->
          <p
            v-if="validationError"
            role="alert"
            class="mt-3 text-sm text-atlas-error"
          >
            {{ validationError }}
          </p>

          <!-- Upload button -->
          <div class="mt-5">
            <button
              type="button"
              class="atlas-focus-ring w-full inline-flex items-center justify-center rounded-atlas px-4 py-2.5 text-sm font-medium transition-colors"
              :class="
                canUpload
                  ? 'bg-atlas-brand text-white hover:bg-atlas-brand-hover'
                  : 'bg-atlas-text-disabled text-white cursor-not-allowed opacity-60'
              "
              :disabled="!canUpload || state === 'uploading'"
              @click="handleUpload"
            >
              <svg
                v-if="state === 'uploading'"
                class="animate-spin -ml-0.5 mr-2 size-4"
                viewBox="0 0 24 24"
                fill="none"
                aria-hidden="true"
              >
                <circle
                  class="opacity-25"
                  cx="12"
                  cy="12"
                  r="10"
                  stroke="currentColor"
                  stroke-width="4"
                />
                <path
                  class="opacity-75"
                  fill="currentColor"
                  d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
                />
              </svg>
              {{ state === 'uploading' ? 'Uploading…' : 'Upload and analyze' }}
            </button>
          </div>
        </div>

        <!-- Format guide -->
        <ImportFormatGuide />
      </div>
    </template>
  </div>
</template>
